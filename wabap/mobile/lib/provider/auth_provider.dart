import 'dart:async';

import 'package:wabap/backend/backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/main.dart' show WabapApp;

final authProvider = ChangeNotifierProvider<AuthModel>((ref) => AuthModel());

class AuthModel extends ChangeNotifier {
  AuthSessionInfo? _sessionValue;
  bool _isLoadingValue = false;
  String? _tmpUserId;
  String? _tmpName;
  String? _tmpClientName;

  /// Set once [fetchSession] has a definitive answer (usable session, or
  /// confirmed signed out). Without it the ~17 screens that read the getters
  /// from build() re-hit fetchAuthSession() on every single frame.
  bool _sessionResolved = false;

  /// Coalesces concurrent calls: HomeScreen.build alone reads four auth
  /// getters, each of which used to fire its own fetchAuthSession().
  Future<void>? _fetchInFlight;

  /// Cooldown for TRANSIENT failures (offline / timeout) so we do retry, but
  /// not once per frame.
  DateTime? _lastFetchAttempt;
  static const Duration _fetchRetryCooldown = Duration(seconds: 5);

  bool _signingOut = false;
  bool _disposed = false;

  StreamSubscription<AuthEvent>? _authSubscription;

  /// Session utilisable : jeton d'identité valide (rafraîchi par [CognitoAuth.currentSession]).
  @visibleForTesting
  static bool isUsableSession(AuthSessionInfo? session) => session != null;

  String? get myId => _tmpUserId ?? _getSession()?.sub;

  String? get myTrueId => _getSession()?.sub;

  bool get isAdmin => _getSession()?.groups.contains('admin') ?? false;

  bool get isSuperAdmin => _getSession()?.groups.contains('wabap') ?? false;

  List<String> get groups => _getSession()?.groups ?? const [];

  bool get isCourier => groups.contains('livreur');

  /// Livreurs et équipes Wabap utilisent l'accueil des tournées (V1) ;
  /// les autres comptes (particuliers, clients) arrivent sur les courses à la demande.
  bool get usesTourneeHome => isCourier || isAdmin || isSuperAdmin;

  set myId(tmpUserId) {
    _tmpUserId = tmpUserId;
  }

  String? get name {
    if (_tmpName != null) return _tmpName;
    final giveName = getAttribute("given_name");
    return giveName ?? _getSession()?.username;
  }

  String? get clientName {
    if (_tmpClientName != null) return _tmpClientName;
    return getAttribute("custom:clientName");
  }

  set name(tmpName) {
    _tmpName = tmpName;
    _safeNotify();
  }

  set clientName(tmpClientName) {
    _tmpClientName = tmpClientName;
    _safeNotify();
  }

  bool get isLoading => _isLoadingValue;

  //setter
  set _isLoading(bool value) {
    _isLoadingValue = value;
    _safeNotify();
  }

  set _session(AuthSessionInfo? value) {
    _sessionValue = value;
    _sessionResolved = isUsableSession(value);
    _safeNotify();
  }

  /// Attribut de l'utilisateur (given_name, email, custom:clientName…), lu dans le jeton d'identité
  String? getAttribute(String name) => _sessionValue?.attribute(name);

  /// Wipes every trace of the previous account and sends the UI back to the
  /// root route. Does NOT sign out of Cognito — see [_forceSignOut] for that.
  void _clearSession() {
    _sessionValue = null;
    _tmpUserId = null;
    _tmpName = null;
    _tmpClientName = null; // logout() used to leak this to the next account
    _sessionResolved = true; // "signed out" is a definitive answer
    _lastFetchAttempt = null;

    _runWhenSafe(() {
      // The app has no router: main.dart only swaps `home:` between HomeScreen
      // and LoginScreen, which does NOT dismiss routes pushed on top of it
      // (tournee, scanner, signature, dialogs). Pop to the root so LoginScreen
      // is actually what the driver sees.
      final navigator = WabapApp.navigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      if (!_disposed) notifyListeners();
    });
  }

  /// Signs out of Cognito (best effort) then clears local state.
  Future<void> _forceSignOut(String reason) async {
    if (_signingOut) return;
    _signingOut = true;
    safePrint('AuthModel: forced sign-out ($reason)');
    try {
      await CognitoAuth.instance.signOut().timeout(const Duration(seconds: 15));
    } catch (e) {
      // Must never block the recovery.
      safePrint('AuthModel: signOut failed during forced sign-out, ignored: $e');
    } finally {
      _clearSession();
      _signingOut = false;
    }
  }

  /// notifyListeners() is reachable from paths that can run while Flutter is
  /// mid-build (a getter read during build kicks fetchSession(); an auth
  /// event can land on any event-loop turn). Notifying then throws
  /// "setState() or markNeedsBuild() called during build", and [_clearSession]
  /// also touches the Navigator. Defer whenever that is the case.
  void _safeNotify() => _runWhenSafe(() {
        if (!_disposed) notifyListeners();
      });

  void _runWhenSafe(VoidCallback action) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) action();
      });
      return;
    }
    action();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

  /// Écoute les événements de session (connexion, déconnexion, session expirée).
  /// À appeler avant le premier [fetchSession].
  void initHubListener() {
    if (_authSubscription != null) return;
    _authSubscription = CognitoAuth.instance.events.listen((event) {
      // Ne doit jamais lever d'exception : l'abonnement serait perdu.
      try {
        switch (event) {
          case AuthEvent.signedIn:
            _sessionResolved = false;
            _lastFetchAttempt = null;
            unawaited(fetchSession());
            break;
          case AuthEvent.sessionExpired:
            unawaited(_forceSignOut('session expired'));
            break;
          case AuthEvent.signedOut:
            _clearSession();
            break;
        }
      } catch (e) {
        safePrint('AuthModel: error handling auth event $event: $e');
      }
    });
  }

  /// Never throws and never completes with an error: it is awaited by
  /// `initApp` (where an error would strand the app on ErrorScreen) and also
  /// fired-and-forgotten from build() via [_getSession].
  Future<void> fetchSession() async {
    if (_sessionResolved && isUsableSession(_sessionValue)) return;
    if (_sessionResolved && _sessionValue == null) return;

    final inFlight = _fetchInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final last = _lastFetchAttempt;
    if (last != null && DateTime.now().difference(last) < _fetchRetryCooldown) {
      return; // transient-failure cooldown: do not retry once per frame
    }
    _lastFetchAttempt = DateTime.now();

    final future = _doFetchSession();
    _fetchInFlight = future;
    try {
      await future;
    } finally {
      _fetchInFlight = null;
    }
  }

  Future<void> _doFetchSession() async {
    try {
      final session = await CognitoAuth.instance.currentSession().timeout(const Duration(seconds: 30));
      if (session == null) {
        _clearSession();
        return;
      }
      _sessionValue = session;
      _sessionResolved = true;
      _safeNotify();
    } on AuthException catch (e) {
      if (e.failure == AuthFailure.sessionExpired) {
        await _forceSignOut('session expired: ${e.message}');
      } else if (e.failure == AuthFailure.network) {
        // Hors ligne : ne PAS déconnecter le livreur (zone blanche en pleine tournée, session valide,
        // file d'attente hors ligne rattachée à myTrueId).
        safePrint('fetchSession: network error (${e.message}), keeping state.');
      } else {
        safePrint('fetchSession: unexpected error, keeping state: $e');
      }
    } on TimeoutException {
      safePrint('fetchSession: timed out, keeping state.');
    } catch (e) {
      safePrint('fetchSession: unexpected error, keeping state: $e');
    }
  }

  AuthSessionInfo? _getSession() {
    // Fire-and-forget: these getters are read from build() and must stay
    // synchronous. fetchSession() coalesces concurrent calls, rate-limits
    // retries and never completes with an error, so discarding it is safe.
    unawaited(fetchSession());
    // Never hand out a session whose tokens cannot be used.
    return isUsableSession(_sessionValue) ? _sessionValue : null;
  }

  /// Les attributs sont lus dans le jeton d'identité : rien à télécharger.
  Future<void> fetchUserAttribute() async {}

  bool isLogin() => _getSession() != null;

  logout() async {
    try {
      await CognitoAuth.instance.signOut();
    } catch (e) {
      safePrint('logout: $e');
    }
    _clearSession();
  }

  Future<AuthError?> signInUser(String username, String password) async {
    AuthError? error;
    _isLoading = true;
    try {
      final step = await CognitoAuth.instance.signIn(username, password);
      error = await _afterSignIn(step);
    } on AuthException catch (e) {
      switch (e.failure) {
        case AuthFailure.userNotFound:
          error = AuthError.userNotFound;
          break;
        case AuthFailure.network:
          error = AuthError.networkError;
          break;
        case AuthFailure.wrongPassword:
          error = AuthError.passwordIncorrect;
          break;
        default:
          error = AuthError.unknownError;
      }
      safePrint('Error signing in: (${e.failure}) ${e.message}');
    }
    _isLoading = false;
    return error;
  }

  Future<AuthError?> _afterSignIn(SignInStep step) async {
    switch (step) {
      case SignInStep.done:
        final session = await CognitoAuth.instance.currentSession();
        if (session == null) return AuthError.unknownError;
        _session = session;
        safePrint('User ID (sub): ${session.sub}');
        return null;
      case SignInStep.newPasswordRequired:
        return AuthError.confirmSignInWithNewPassword;
      case SignInStep.resetPasswordRequired:
        return AuthError.resetPassword;
    }
  }

  Future<AuthError?> showPasswordConfirmationDialog(BuildContext context) async {
    _isLoading = true;
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final passwordController2 = TextEditingController();

    var cancel = false;

    final GlobalKey<FormState> formKey = GlobalKey();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  const Text(
                    "Première connexion",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text("Vous vous connectez pour la première fois, merci de choisir un mot de passe :"),
                  TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: "Mot de passe"),
                      obscureText: true,
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return "Merci de saisir un mot de passe.";
                        } else if (value.length < 8) {
                          return "Minimum 8 caractères.";
                        }

                        return null;
                      }),
                  TextFormField(
                      controller: passwordController2,
                      decoration: const InputDecoration(labelText: "Confirmez mot de passe"),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Merci de saisir un mot de passe.";
                        } else if (value.length < 8) {
                          return "Minimum 8 caractères.";
                        } else if (passwordController.text != value) {
                          return "Pas identique";
                        }

                        return null;
                      }),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text("Merci de renseigner votre adresse mail :"),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: "Email"),
                    validator: (value) {
                      const pattern = r"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'"
                          r'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-'
                          r'\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*'
                          r'[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4]'
                          r'[0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9]'
                          r'[0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\'
                          r'x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])';
                      final regex = RegExp(pattern);

                      return value == null || value.isEmpty || !regex.hasMatch(value)
                          ? 'Entrez une adresse mail valide'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Annuler"),
              onPressed: () {
                cancel = true;
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Confirmer"),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );

    AuthError? error;
    if (!cancel) {
      try {
        await CognitoAuth.instance.completeNewPassword(passwordController.text, email: emailController.text.trim());
        error = await _afterSignIn(SignInStep.done);
      } catch (e) {
        safePrint('completeNewPassword: $e');
        error = AuthError.unknownError;
      }
    }

    _isLoading = false;
    return error;
  }

  Future<AuthError?> showResetPassword(String username, BuildContext context, WidgetRef ref) async {
    _isLoading = true;
    var isLoadingCode = false;
    var messageCode = "";
    final codeController = TextEditingController();
    final passwordController = TextEditingController();
    final passwordController2 = TextEditingController();

    var cancel = false;

    final GlobalKey<FormState> formKey = GlobalKey();

    await showDialog(
      context: context,
      builder: (contextDialog) {
        return AlertDialog(
          content: StatefulBuilder(builder: (context, setState) {
            return SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Nouveau mot de passe",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    const Text("Vous devez saisir un nouveau mot de passe :"),
                    TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: "Mot de passe"),
                        obscureText: true,
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return "Merci de saisir un mot de passe.";
                          } else if (value.length < 8) {
                            return "Minimum 8 caractères.";
                          }
                          return null;
                        }),
                    TextFormField(
                        controller: passwordController2,
                        decoration: const InputDecoration(labelText: "Confirmez mot de passe"),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Merci de saisir un mot de passe.";
                          } else if (value.length < 8) {
                            return "Minimum 8 caractères.";
                          } else if (passwordController.text != value) {
                            return "Pas identique";
                          }
                          return null;
                        }),
                    const SizedBox(
                      height: 20,
                    ),
                    const Text("Merci de saisir le code de vérification recu par mail :"),
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(labelText: "Code"),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Merci de saisir un mot de passe.";
                        } else if (value.length < 6) {
                          return "Minimum 6 caractères.";
                        }
                        return null;
                      },
                    ),
                    if (!isLoadingCode && messageCode.isEmpty)
                      TextButton(
                        child: const Text("Demander un nouveau code"),
                        onPressed: () async {
                          setState(
                            () {
                              isLoadingCode = true;
                            },
                          );
                          try {
                            final destination = await CognitoAuth.instance.forgotPassword(username);
                            messageCode = "Un nouveau code a été envoyé par mail à ${destination ?? "??"}";
                          } catch (e) {
                            messageCode = "Envoi du code impossible : $e";
                          }
                          setState(
                            () {
                              isLoadingCode = false;
                            },
                          );
                        },
                      ),
                    if (!isLoadingCode && messageCode.isNotEmpty)
                      Text(
                        messageCode,
                        style: const TextStyle(fontSize: 12, color: C.labelColor),
                      ),
                    if (isLoadingCode)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            )),
                      )
                  ],
                ),
              ),
            );
          }),
          actions: [
            TextButton(
              child: const Text("Annuler"),
              onPressed: () {
                cancel = true;
                Navigator.of(contextDialog).pop();
              },
            ),
            TextButton(
              child: const Text("Confirmer"),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(contextDialog).pop();
                }
              },
            ),
          ],
        );
      },
    );

    AuthError? error;
    if (!cancel) {
      try {
        await CognitoAuth.instance.confirmForgotPassword(username, codeController.text, passwordController.text);
        error = await signInUser(username, passwordController.text);
      } catch (e) {
        if (e is AuthException && e.failure == AuthFailure.codeMismatch) {
          error = AuthError.codeResetPasswordInvalide;
        } else {
          error = AuthError.unknownError;
        }
      }
    }

    _isLoading = false;
    return error;
  }
}

enum AuthError {
  resetPassword,
  codeResetPasswordInvalide,
  confirmSignInWithNewPassword,
  invalidCredentials,
  userNotFound,
  passwordIncorrect,
  networkError,
  unknownError,
}

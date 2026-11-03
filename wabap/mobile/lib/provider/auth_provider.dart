import 'dart:async';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wabap/colors.dart';
import 'package:wabap/main.dart' show WabapApp;

final authProvider = ChangeNotifierProvider<AuthModel>((ref) => AuthModel());

class AuthModel extends ChangeNotifier {
  CognitoAuthSession? _sessionValue;
  List<AuthUserAttribute>? _userAttValue;
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

  bool _fetchingAttributes = false;
  bool _signingOut = false;
  bool _disposed = false;

  StreamSubscription<AuthHubEvent>? _hubSubscription;

  /// Whether [session] can actually be used.
  ///
  /// [CognitoAuthSession.isSignedIn] alone is NOT enough. When the refresh
  /// token has expired, fetch_auth_session_state_machine.dart catches the
  /// failure, stores `AuthResult.error(SessionExpiredException(...))` in
  /// userPoolTokensResult, and STILL reports `isSignedIn: true` because the
  /// stale in-memory tokens are non-null. fetchAuthSession() does not throw;
  /// every downstream `.value` read does, synchronously, inside build().
  @visibleForTesting
  static bool isUsableSession(CognitoAuthSession? session) =>
      session != null && session.isSignedIn && session.userPoolTokensResult.valueOrNull != null;

  // Getters. All of them go through `valueOrNull`, never `.value`: on an
  // errored AWSResult `.value` rethrows, and these are read from build().
  String? get myId => _tmpUserId ?? _getSession()?.userSubResult.valueOrNull;

  String? get myTrueId => _getSession()?.userSubResult.valueOrNull;

  bool get isAdmin =>
      _getSession()?.userPoolTokensResult.valueOrNull?.idToken.groups.contains('admin') ?? false;

  bool get isSuperAdmin =>
      _getSession()?.userPoolTokensResult.valueOrNull?.idToken.groups.contains('wabap') ?? false;

  set myId(tmpUserId) {
    _tmpUserId = tmpUserId;
  }

  String? get name {
    if (_tmpName != null) return _tmpName;
    final giveName = getAttribute("given_name");
    return giveName ?? _getSession()?.userPoolTokensResult.valueOrNull?.username;
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

  set _session(CognitoAuthSession? value) {
    _sessionValue = value;
    _sessionResolved = isUsableSession(value);
    unawaited(fetchUserAttribute());
    _safeNotify();
  }

  String? getAttribute(String name) {
    if (_userAttValue != null) {
      for (var att in _userAttValue!) {
        if (att.userAttributeKey.key == name.toLowerCase()) {
          return att.value;
        }
      }
    }
    return null;
  }

  /// Wipes every trace of the previous account and sends the UI back to the
  /// root route. Does NOT sign out of Cognito — see [_forceSignOut] for that.
  void _clearSession() {
    _sessionValue = null;
    _userAttValue = null;
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
      await Amplify.Auth.signOut().timeout(const Duration(seconds: 15));
    } catch (e) {
      // Must never block the recovery.
      safePrint('AuthModel: signOut failed during forced sign-out, ignored: $e');
    } finally {
      _clearSession();
      _signingOut = false;
    }
  }

  /// notifyListeners() is reachable from paths that can run while Flutter is
  /// mid-build (a getter read during build kicks fetchSession(); an Amplify hub
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
    _hubSubscription?.cancel();
    _hubSubscription = null;
    super.dispose();
  }

  /// Must be called AFTER Amplify.configure() and BEFORE the first
  /// [fetchSession]: the Amplify hub is a broadcast stream, so events emitted
  /// before we subscribe are lost — and the launch-time SESSION_EXPIRED is
  /// emitted by that very first fetch.
  void initHubListener() {
    if (_hubSubscription != null) return;
    _hubSubscription = Amplify.Hub.listen(
      HubChannel.Auth,
      (AuthHubEvent event) {
        // Must never throw: listen() uses cancelOnError, so an escaping
        // exception would kill this subscription for the whole process.
        try {
          switch (event.type) {
            case AuthHubEventType.signedIn:
              _sessionResolved = false;
              _lastFetchAttempt = null;
              unawaited(fetchSession());
              break;
            case AuthHubEventType.sessionExpired:
              unawaited(_forceSignOut('hub: session expired'));
              break;
            case AuthHubEventType.signedOut:
            case AuthHubEventType.userDeleted:
              _clearSession();
              break;
          }
        } catch (e) {
          safePrint('AuthModel: error handling hub ${event.type}: $e');
        }
      },
      onError: (Object e, StackTrace s) {
        // cancelOnError means the subscription is already dead here.
        safePrint('AuthModel: auth hub stream error: $e');
        _hubSubscription = null;
        _runWhenSafe(initHubListener);
      },
    );
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
      final rep = await Amplify.Auth.fetchAuthSession().timeout(const Duration(seconds: 30));
      if (rep is! CognitoAuthSession || !rep.isSignedIn) {
        _clearSession();
        return;
      }

      if (rep.userPoolTokensResult.valueOrNull == null) {
        // THE BUG: isSignedIn is true but the tokens are unusable because the
        // refresh token expired. fetchAuthSession() did NOT throw, so the
        // `on SessionExpiredException` catch below never fired and the broken
        // session used to be stored — then `.value` threw inside build().
        final cause = rep.userPoolTokensResult.exception;
        await _forceSignOut('signed in without usable tokens (${cause.runtimeType})');
        return;
      }

      _sessionValue = rep;
      _sessionResolved = true;
      await fetchUserAttribute();
      _safeNotify();
    } on SessionExpiredException catch (e) {
      await _forceSignOut('session expired: ${e.message}');
    } on AuthNotAuthorizedException catch (e) {
      await _forceSignOut('not authorized: ${e.message}');
    } on SignedOutException {
      _clearSession();
    } on TimeoutException {
      // Offline / slow network. Do NOT sign the driver out: they may be in a
      // dead zone mid-tournee with a perfectly valid session, and the offline
      // queue scopes its entries with myTrueId.
      safePrint('fetchSession: timed out, keeping state.');
    } on NetworkException catch (e) {
      safePrint('fetchSession: network error (${e.message}), keeping state.');
    } catch (e) {
      safePrint('fetchSession: unexpected error, keeping state: $e');
    }
  }

  CognitoAuthSession? _getSession() {
    // Fire-and-forget: these getters are read from build() and must stay
    // synchronous. fetchSession() coalesces concurrent calls, rate-limits
    // retries and never completes with an error, so discarding it is safe.
    unawaited(fetchSession());
    // Never hand out a session whose tokens cannot be used.
    return isUsableSession(_sessionValue) ? _sessionValue : null;
  }

  Future<void> fetchUserAttribute() async {
    if (_fetchingAttributes) return;
    // Deliberately not isLogin(): that goes through _getSession() ->
    // fetchSession() and would re-enter while we are inside it.
    if (!isUsableSession(_sessionValue) || _userAttValue != null) return;

    _fetchingAttributes = true;
    try {
      _userAttValue = await Amplify.Auth.fetchUserAttributes().timeout(const Duration(seconds: 30));
      _safeNotify();
    } catch (e) {
      // Attributes are cosmetic (given_name / custom:clientName). They must
      // never brick the app; the next fetchSession() retries them.
      safePrint('fetchUserAttribute ignored: $e');
    } finally {
      _fetchingAttributes = false;
    }
  }

  bool isLogin() => _getSession() != null;

  logout() async {
    try {
      await Amplify.Auth.signOut();
    } on AuthException catch (e) {
      safePrint(e.message);
    }
    _clearSession();
  }

  Future<AuthError?> signInUser(String username, String password) async {
    AuthError? error;
    _isLoading = true;
    try {
      final result = await Amplify.Auth.signIn(
        username: username,
        password: password,
      );
      error = await _handleSignInResult(result);
    } on AuthException catch (e) {
      if (e is UserNotFoundException) {
        error = AuthError.userNotFound;
      } else if (e is NetworkException) {
        error = AuthError.networkError;
      } else if (e is NotAuthorizedServiceException) {
        error = AuthError.passwordIncorrect;
      } else {
        error = AuthError.unknownError;
      }
      safePrint('Error signing in: (${e.runtimeType}) ${e.message}');
    }
    _isLoading = false;
    return error;
  }

  Future<AuthError?> _handleSignInResult(SignInResult result) async {
    if (result.nextStep.signInStep == AuthSignInStep.done) {
      safePrint('Sign in is complete');

      final authSession = await Amplify.Auth.fetchAuthSession();

      if (authSession is CognitoAuthSession && isUsableSession(authSession)) {
        _session = authSession;
        safePrint("User ID (userSub): ${authSession.userSubResult.valueOrNull}");
        return null;
      } else {
        safePrint("Session is not a usable Cognito session");
        return AuthError.unknownError;
      }
    } else if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithNewPassword) {
      return AuthError.confirmSignInWithNewPassword;
    } else if (result.nextStep.signInStep == AuthSignInStep.resetPassword) {
      return AuthError.resetPassword;
    } else {
      safePrint('Sign in EROOR : ${result.nextStep.signInStep}');
      return AuthError.unknownError;
    }
  }

  Future<AuthError?> _handleResetPasswordResult(ResetPasswordResult result) async {
    if (result.nextStep.updateStep == AuthResetPasswordStep.done) {
      safePrint('Reset Password is complete');

      final authSession = await Amplify.Auth.fetchAuthSession();

      if (authSession is CognitoAuthSession && isUsableSession(authSession)) {
        _session = authSession;
        safePrint("User ID (userSub): ${authSession.userSubResult.valueOrNull}");
        return null;
      } else {
        safePrint("Session is not a usable Cognito session");
        return AuthError.unknownError;
      }
    } else {
      safePrint('Reset password in EROOR : $result');
      return AuthError.unknownError;
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
      final options = ConfirmSignInOptions(
          pluginOptions:
              CognitoConfirmSignInPluginOptions(userAttributes: {CognitoUserAttributeKey.email: emailController.text}));

      try {
        final result = await Amplify.Auth.confirmSignIn(confirmationValue: passwordController.text, options: options);
        error = await _handleSignInResult(result);
      } catch (e) {
        error = null;
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
                          final result = await Amplify.Auth.resetPassword(
                            username: username,
                          );
                          safePrint(">>>>>> : $result");
                          if (result.nextStep.updateStep == AuthResetPasswordStep.confirmResetPasswordWithCode) {
                            messageCode =
                                "Un nouveau code a été envoyé par mail à ${result.nextStep.codeDeliveryDetails?.destination ?? "??"}";
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
        final result = await Amplify.Auth.confirmResetPassword(
            username: username, newPassword: passwordController.text, confirmationCode: codeController.text);
        _handleResetPasswordResult(result);
      } catch (e) {
        if (e is CodeMismatchException) {
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

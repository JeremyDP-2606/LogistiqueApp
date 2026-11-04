// Connexion Cognito (protocole SRP) sans Amplify : connexion, premier mot de passe, mot de passe oublié,
// inscription, session conservée sur l'appareil et rafraîchie automatiquement.
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Session utilisable : jeton d'identité et ses informations
class AuthSessionInfo {
  final String idToken;
  final Map<String, dynamic> claims;
  const AuthSessionInfo(this.idToken, this.claims);

  String get sub => claims['sub'] as String;
  String? get username => (claims['cognito:username'] ?? claims['username']) as String?;
  List<String> get groups => ((claims['cognito:groups'] as List?) ?? const []).map((e) => '$e').toList();
  String? attribute(String name) => claims[name] as String?;
}

enum SignInStep { done, newPasswordRequired, resetPasswordRequired }

enum AuthFailure { userNotFound, wrongPassword, userNotConfirmed, codeMismatch, network, sessionExpired, unknown }

class AuthException implements Exception {
  final AuthFailure failure;
  final String message;
  const AuthException(this.failure, this.message);
  @override
  String toString() => message;
}

enum AuthEvent { signedIn, signedOut, sessionExpired }

/// Stockage persistant de la session Cognito (préférences de l'appareil)
class _PrefsStorage extends CognitoStorage {
  Future<SharedPreferences> get _p => SharedPreferences.getInstance();
  @override
  Future<dynamic> getItem(String key) async => (await _p).getString(key);
  @override
  Future<dynamic> setItem(String key, value) async {
    await (await _p).setString(key, '$value');
    return value;
  }
  @override
  Future<dynamic> removeItem(String key) async {
    final p = await _p;
    final v = p.getString(key);
    await p.remove(key);
    return v;
  }
  @override
  Future<void> clear() async {
    final p = await _p;
    for (final k in p.getKeys().where((k) => k.startsWith('CognitoIdentityServiceProvider.'))) {
      await p.remove(k);
    }
  }
}

class CognitoAuth {
  static CognitoAuth instance = CognitoAuth();

  final CognitoStorage _storage = _PrefsStorage();
  late final CognitoUserPool _pool = CognitoUserPool(BackendConfig.userPoolId, BackendConfig.clientId, storage: _storage);
  CognitoUser? _pending; // utilisateur devant choisir un nouveau mot de passe
  final _events = StreamController<AuthEvent>.broadcast();

  Stream<AuthEvent> get events => _events.stream;

  static AuthException _map(Object e) {
    if (e is AuthException) return e;
    if (e is CognitoClientException) {
      final msg = e.message ?? 'Erreur Cognito';
      switch (e.code) {
        case 'UserNotFoundException':
          return AuthException(AuthFailure.userNotFound, msg);
        case 'NotAuthorizedException':
          return AuthException(AuthFailure.wrongPassword, msg);
        case 'UserNotConfirmedException':
          return AuthException(AuthFailure.userNotConfirmed, msg);
        case 'CodeMismatchException':
        case 'ExpiredCodeException':
          return AuthException(AuthFailure.codeMismatch, msg);
        case 'NetworkError':
          return AuthException(AuthFailure.network, msg);
      }
      return AuthException(AuthFailure.unknown, msg);
    }
    if (e is SocketException || e is ClientException || e is TimeoutException) return AuthException(AuthFailure.network, '$e');
    return AuthException(AuthFailure.unknown, '$e');
  }

  /// Session en cours (rafraîchie si nécessaire), null si déconnecté.
  /// Lève [AuthException] (sessionExpired) si la session ne peut plus être rafraîchie, ou (network) hors ligne.
  Future<AuthSessionInfo?> currentSession() async {
    final user = await _pool.getCurrentUser();
    if (user == null) return null;
    try {
      final session = await user.getSession();
      if (session == null || !session.isValid()) return null;
      return AuthSessionInfo(session.getIdToken().getJwtToken()!, Map<String, dynamic>.from(session.getIdToken().decodePayload() as Map));
    } catch (e) {
      final m = _map(e);
      if (m.failure == AuthFailure.wrongPassword) {
        throw const AuthException(AuthFailure.sessionExpired, 'Session expirée : reconnectez-vous');
      }
      throw m;
    }
  }

  Future<String?> idToken() async {
    try {
      return (await currentSession())?.idToken;
    } catch (_) {
      return null;
    }
  }

  Future<SignInStep> signIn(String username, String password) async {
    final user = CognitoUser(username, _pool, storage: _storage);
    try {
      await user.authenticateUser(AuthenticationDetails(username: username, password: password));
      _events.add(AuthEvent.signedIn);
      return SignInStep.done;
    } on CognitoUserNewPasswordRequiredException {
      _pending = user;
      return SignInStep.newPasswordRequired;
    } on CognitoClientException catch (e) {
      if (e.code == 'PasswordResetRequiredException') return SignInStep.resetPasswordRequired;
      throw _map(e);
    } catch (e) {
      throw _map(e);
    }
  }

  /// Premier mot de passe (compte créé par un administrateur) ; e-mail éventuellement exigé.
  Future<void> completeNewPassword(String password, {String? email}) async {
    final user = _pending;
    if (user == null) throw const AuthException(AuthFailure.unknown, 'Aucun changement de mot de passe en attente');
    try {
      await user.sendNewPasswordRequiredAnswer(password, {if (email != null && email.isNotEmpty) 'email': email});
      _pending = null;
      _events.add(AuthEvent.signedIn);
    } catch (e) {
      throw _map(e);
    }
  }

  /// Envoie un code de réinitialisation ; renvoie la destination masquée (ex. j***@g***.com)
  Future<String?> forgotPassword(String username) async {
    try {
      final r = await CognitoUser(username, _pool, storage: _storage).forgotPassword();
      final details = r is Map ? r['CodeDeliveryDetails'] : null;
      return details is Map ? details['Destination'] as String? : null;
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> confirmForgotPassword(String username, String code, String newPassword) async {
    try {
      await CognitoUser(username, _pool, storage: _storage).confirmPassword(code, newPassword);
    } catch (e) {
      throw _map(e);
    }
  }

  /// Inscription d'un particulier ; renvoie true si le compte est déjà confirmé
  Future<bool> signUp(String username, String password, Map<String, String> attributes) async {
    try {
      final r = await _pool.signUp(username, password, userAttributes: attributes.entries.map((e) => AttributeArg(name: e.key, value: e.value)).toList());
      return r.userConfirmed ?? false;
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> confirmSignUp(String username, String code) async {
    try {
      await CognitoUser(username, _pool, storage: _storage).confirmRegistration(code);
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> resendSignUpCode(String username) async {
    try {
      await CognitoUser(username, _pool, storage: _storage).resendConfirmationCode();
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> signOut() async {
    final user = await _pool.getCurrentUser();
    try {
      await user?.signOut();
    } catch (_) {
      await user?.clearCachedTokens();
    }
    await _storage.clear();
    _events.add(AuthEvent.signedOut);
  }

  /// Session devenue inutilisable (jeton de rafraîchissement expiré ou révoqué)
  void reportExpired() => _events.add(AuthEvent.sessionExpired);
}

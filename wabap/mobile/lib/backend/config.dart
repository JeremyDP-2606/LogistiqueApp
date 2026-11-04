// Configuration de l'app (à la compilation : --dart-define=API_URL=… etc.).
class BackendConfig {
  /// URL de l'API GraphQL Wabap (le temps réel utilise la même adresse en wss://)
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://api.wabap.fr/graphql');
  static const userPoolId = String.fromEnvironment('COGNITO_USER_POOL_ID', defaultValue: 'us-east-1_c5SbPwJEZ');
  static const clientId = String.fromEnvironment('COGNITO_CLIENT_ID', defaultValue: '6g7521kgouj9fjsg9aibi4h650');

  static String get realtimeUrl => apiUrl.replaceFirst(RegExp('^http'), 'ws');
  static String get restUrl => apiUrl.replaceFirst(RegExp(r'/graphql/?$'), '');
}

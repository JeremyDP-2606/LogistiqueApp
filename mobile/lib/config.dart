/// URL de l'API. Surcharger au lancement :
///   flutter run --dart-define=API_URL=http://192.168.1.20:4000
/// Par défaut : 10.0.2.2 = machine hôte vue depuis l'émulateur Android.
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:4000');

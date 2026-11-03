# Wabap V2

Plateforme de livraison Wabap : tournées récurrentes (V1) et courses à la demande ouvertes à tous (V2).

| Dossier | Contenu |
|---|---|
| `mobile/` | App Flutter (livreurs et clients) et backend AWS Amplify (`mobile/amplify/` : AppSync GraphQL, DynamoDB, Lambda Node.js, Cognito, S3) |
| `backoffice/` | Back-office Vue.js 3 + Vuetify |

## Secrets et configuration

Aucune clé ni aucun mot de passe n'est versionné. Chaque environnement doit les fournir ainsi :

| Secret | Où le définir |
|---|---|
| Clé Google Maps, app Android | `MAPS_API_KEY=...` dans `mobile/android/local.properties` |
| Clé Google Maps, app iOS | `mobile/ios/Flutter/Secrets.xcconfig` (modèle : `Secrets.xcconfig.example`) |
| Clé Google Maps, code Dart (cartes statiques, itinéraires) | `flutter run --dart-define=GOOGLE_MAPS_API_KEY=...` |
| Clé Google Maps, back-office | `VITE_GOOGLE_MAPS_API_KEY` dans `backoffice/.env` (modèle : `.env.example`) |
| Clé Google Maps, Lambda `createTournee`, `importCSV`, `importExcel` | secret Amplify `GOOGLE_MAPS_API_KEY` (`amplify update function` > « Configure secret values ») |
| Accès RouteXL, Lambda `createTournee` | secret Amplify `ROUTEXL_AUTH` (identifiant:mot de passe encodé en base64) |
| Accès SFTP, Lambda `importCSV` | dans l'événement de la règle planifiée, jamais dans le code |
| Configuration Amplify de l'app | `mobile/lib/amplifyconfiguration.dart`, généré par `amplify pull` |

Les clés présentes dans la V1 ont été publiées dans l'app et le back-office : elles doivent être régénérées et restreintes (par application Android/iOS, par domaine pour le back-office, par API côté serveur).

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

## V2 : courses à la demande

| Partie | Emplacement |
|---|---|
| Schéma GraphQL (modèles `Course`, `CourseSecret`, `CourseEvent`, `CourierProfile`, `Tarif`, opérations et abonnements) | `mobile/amplify/backend/api/wabap/schema.graphql` (fin du fichier) |
| Lambda `courseApi` (toutes les règles métier) | `mobile/amplify/backend/function/courseApi/` |
| Écrans de l'app (client, livreur, inscription, paiement) | `mobile/lib/v2/` |
| Écrans du back-office (courses, fiche course, tarifs) | `backoffice/src/views/Course*.vue`, `TarifsView.vue`, `src/api/courseService.js` |

Fonctionnement d'une course : devis (Google Routes) → commande et autorisation de la carte (Stripe) → envoi aux livreurs de la zone → acceptation (un seul livreur, protégée côté base) → étapes → remise validée par le code à 4 chiffres du destinataire → encaissement. Une annulation libère l'autorisation de paiement. Les clients professionnels dont la grille indique « facturation mensuelle » ne paient pas par carte.

### Tests

```bash
cd mobile/amplify/backend/function/courseApi && (cd test/sdk && npm install) && node --test test/*.test.js
```
```bash
cd mobile && flutter test test/v2_courses_test.dart
```

### Mise en service (à faire dans l'ordre, d'abord sur l'environnement `dev`)

1. **Fusionner le schéma avec celui de la production.** Le schéma de l'archive V1 n'est pas à jour : l'app appelle `invokeLambdaRapportTournee`, qui n'y figure pas. Récupérer le schéma déployé (`amplify pull`) et y reporter la partie V2 avant tout `amplify push`, sinon cette mutation disparaîtrait.
2. **Identifiant de l'API par environnement** : paramètre `graphqlApiId` de la fonction `courseApi` dans `amplify/team-provider-info.json`. La valeur `dev` reprend celle écrite dans la Lambda V1 `createTournee` ; pour `prod`, la même Lambda indique `nfdn7djf2fcbdjz44rvjidtaf4` (à vérifier).
3. **Secrets dans SSM Parameter Store** (type SecureString) :
   - `/wabap/<env>/STRIPE_SECRET_KEY` : clé secrète Stripe (`sk_test_…` en dev) ;
   - `/wabap/<env>/GOOGLE_MAPS_API_KEY` : clé serveur avec l'API **Routes** activée.
4. **Google Cloud** : activer Routes API, Places API (New) et Geocoding API ; une clé par usage, restreinte (serveur, application Android, application iOS, domaine du back-office).
5. **Stripe** : créer le compte, activer les cartes (et Apple Pay / Google Pay si souhaité).
6. `amplify push` sur `dev`, puis compiler l'app avec ses clés :
   ```bash
   flutter run --dart-define=GOOGLE_MAPS_API_KEY=... --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```
7. **Livreurs** : les comptes du groupe `livreur` existants voient le bouton « Courses à la demande » ; leur profil (véhicule) est créé à leur première mise en disponibilité.
8. **Tarifs** : la grille par défaut est intégrée à la Lambda ; l'écran Tarifs du back-office permet de l'ajuster et de créer des grilles par client professionnel (par exemple la TVA à 8,5 % en Martinique et en Guadeloupe).

### Avant l'ouverture au public

- Conditions générales de vente, mentions RGPD, contrat et statut des livreurs indépendants.
- Webhooks Stripe pour le rapprochement des paiements. Une autorisation de carte expire au bout de 7 jours : les courses restées en « Problème » doivent être traitées (encaissement ou annulation) avant ce délai.
- Notifications push (Firebase Cloud Messaging) pour les livreurs hors de l'app, et lien de suivi envoyé au destinataire par SMS.

### Points relevés dans la V1

- Les Lambda V1 tournent sous Node.js 16 : AWS ne permettra plus de les mettre à jour après le 31 août 2027.
- Le transformer Amplify signale que, sur plusieurs modèles V1 (Tournee, Inscription, Colis…), un propriétaire peut réattribuer la propriété d'un enregistrement (par exemple un livreur peut modifier le champ livreur d'une tournée). Des règles d'autorisation par champ corrigeraient ce point.
- Le magasin de clés de signature Android présent dans l'archive (`android/FOa3VztdaNW8`) n'a pas été importé : il doit rester hors du dépôt.

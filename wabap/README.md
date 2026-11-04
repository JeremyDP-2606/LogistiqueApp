# Wabap V2

Plateforme de livraison Wabap : tournées récurrentes (V1) et courses à la demande ouvertes à tous (V2).

| Dossier | Contenu |
|---|---|
| `backend/` | API Node.js (GraphQL, temps réel, routes REST) : remplace Amplify ; Cognito, DynamoDB, S3 et SES conservés |
| `mobile/` | App Flutter (livreurs et clients) |
| `backoffice-react/` | Back-office de la plateforme (React) |
| `backoffice/` | Back-office V1 (Vue.js 3 + Vuetify) |
| `docs/MIGRATION.md` | Bascule d'Amplify vers l'API Node.js |

Architecture : applications → API Node.js (`backend/`, image Docker) → DynamoDB, S3, SES ; connexion des utilisateurs par
Cognito (jeton vérifié par l'API). Plus aucun identifiant AWS dans les navigateurs ni dans l'app.

## Secrets et configuration

Aucune clé ni aucun mot de passe n'est versionné. Chaque environnement doit les fournir ainsi :

| Secret | Où le définir |
|---|---|
| Clé Google Maps, app Android | `MAPS_API_KEY=...` dans `mobile/android/local.properties` |
| Clé Google Maps, app iOS | `mobile/ios/Flutter/Secrets.xcconfig` (modèle : `Secrets.xcconfig.example`) |
| Clé Google Maps, code Dart (cartes statiques, itinéraires) | `flutter run --dart-define=GOOGLE_MAPS_API_KEY=...` |
| Clé Google Maps, back-office | `VITE_GOOGLE_MAPS_API_KEY` dans `backoffice/.env` (modèle : `.env.example`) |
| Clés du serveur (Google Maps, RouteXL, Stripe, signature des étiquettes), accès SFTP | variables d'environnement du conteneur de l'API (modèle : `backend/.env.example`) |
| Adresse de l'API et Cognito pour l'app | `flutter run --dart-define=API_URL=... --dart-define=COGNITO_USER_POOL_ID=... --dart-define=COGNITO_CLIENT_ID=...` |
| Adresse de l'API et Cognito pour les back-offices | `VITE_API_URL`, `VITE_COGNITO_USER_POOL_ID`, `VITE_COGNITO_CLIENT_ID` (modèles `.env.example`) |

Les clés présentes dans la V1 ont été publiées dans l'app et le back-office : elles doivent être régénérées et restreintes (par application Android/iOS, par domaine pour le back-office, par API côté serveur).

## Plateforme de livraison (spec fonctionnelle v0.1)

Le mode « course instantanée » du premier prototype a été retiré : une course payée devient une demande que le dispatcher insère dans une tournée.

| Partie | Emplacement |
|---|---|
| Schéma GraphQL (configuration, demandes, colis, historique, tournées, points, rémunération) | `backend/schema/schema.graphql` (après les modèles V1) |
| Logique métier (34 opérations) | `backend/src/delivery/` |
| App Flutter : client à la course, livreur sur tournées, inscription, paiement | `mobile/lib/v2/` |
| Back-office React (dispatch, finance, configuration, espace client) | `backoffice-react/` |
| Serveur de démonstration sans AWS (données fictives) | `cd backend && npm run demo` |

Couvert par lot :
1. **Socle** : ingestion (API, import CSV, saisie, app) avec mapping par connecteur, normalisation (adresses, téléphones y compris DOM), défauts du client, géocodage, file d'anomalies, donnée brute conservée ; colis à code signé ; profils de preuve en cascade ; tournées dédiées ou mutualisées, collecte avant livraison, heures limites strictes, gel après démarrage ; historique non modifiable ; vue client cloisonnée côté serveur.
2. **Course à la demande** : prix selon la taille, le délai (1, 2 ou 3 jours) et les km, avec minimum, suppléments, code promo ; grille historisée ; paiement Stripe avant prise en charge ; remboursement si annulation ou échec ; suivi par étapes.
3. **Étiquettes et preuves** : étiquettes PDF 10 × 15 cm (QR + Code 128), étiquettes en réserve, modes strict / souple, envoi automatique B2B ; preuves exigées au point (scan, photo, signature, position, code), écart de position, commentaires prédéfinis.
4. **Rémunération** : grille au km par type de client et jour / nuit, historisée ; répartition en tournée mutualisée ; forfaits et minimum ; validation, relevé mensuel, export CSV.

Pas encore fait : portage des écrans V1 dans le back-office React, optimisation multi-tournées et insertion automatique (phases V2 / V3 de la spec), secteurs dessinés, carte live, forfaits B2B, rapports PDF automatiques, notifications push, documents d'onboarding des livreurs.

### Tests

```bash
cd backend && npm install && npm test
```
```bash
cd backoffice-react && npm install && npm test
```
```bash
cd mobile && flutter test test/platform_contract_test.dart
```

Les fichiers `mobile/test/fixtures/*.json` sont des réponses réelles du serveur (`node backend/scripts/export-fixtures.js mobile/test/fixtures`) : le test de contrat échoue si le format change. Les tests du serveur vérifient aussi que toutes les requêtes GraphQL des trois applications restent valides.

### Mise en service (d'abord sur l'environnement `dev`)

Voir `docs/MIGRATION.md` (bascule depuis Amplify, sans déplacement de données) et `backend/README.md` (configuration,
droits AWS, déploiement Docker). En résumé :

1. Configurer le serveur (`backend/.env.example`), vérifier puis compléter les tables : `npm run tables:check`, `npm run tables:create`.
2. Groupes Cognito `dispatch` et `finance` : y placer les dispatchers et comptables.
3. Configuration initiale dans le back-office : types de client, clients (l'identifiant = attribut `custom:clientName` de leurs utilisateurs), profils de preuve, commentaires prédéfinis, grille des courses, grille de rémunération.
4. Publier les back-offices et l'app avec l'adresse de l'API :
   ```bash
   flutter run --dart-define=API_URL=https://api.wabap.fr/graphql --dart-define=GOOGLE_MAPS_API_KEY=... --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

### Avant l'ouverture au public

- Conditions générales de vente, mentions RGPD (géolocalisation, données des destinataires, durée de conservation des preuves et des traces GPS), contrat des livreurs indépendants.
- Webhooks Stripe pour le rapprochement des paiements et remboursements.
- Imprimantes d'étiquettes : 203 dpi minimum (QR et code-barres relus à cette résolution).

### Points relevés dans la V1

- Les Lambda V1 (Node.js 16) sont remplacées par le serveur : voir `docs/MIGRATION.md` pour leur arrêt.
- Un propriétaire ne peut plus céder un enregistrement à un autre client (contrôle ajouté par le serveur). En revanche un livreur peut toujours modifier les autres champs d'une tournée qui lui est attribuée (règle V1 `livreurID`, opérations read et update) ; des règles par champ restreindraient ce point.
- Les preuves V1 restent rangées sous `public/tournee_<id>/` dans S3 (emplacement historique) ; celles de la plateforme sont privées (`proofs/`). Rendre le préfixe `public/` non public dans la politique du bucket.
- Le magasin de clés de signature Android présent dans l'archive (`android/FOa3VztdaNW8`) n'a pas été importé : il doit rester hors du dépôt.

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

## Plateforme de livraison (spec fonctionnelle v0.1)

Le mode « course instantanée » du premier prototype a été retiré : une course payée devient une demande que le dispatcher insère dans une tournée.

| Partie | Emplacement |
|---|---|
| Schéma GraphQL (configuration, demandes, colis, historique, tournées, points, rémunération) | `mobile/amplify/backend/api/wabap/schema.graphql` (après les modèles V1, inchangés) |
| Fonction `deliveryApi` : toute la logique métier (34 opérations) | `mobile/amplify/backend/function/deliveryApi/` |
| App Flutter : client à la course, livreur sur tournées, inscription, paiement | `mobile/lib/v2/` |
| Back-office React (dispatch, finance, configuration, espace client) | `backoffice-react/` |
| AppSync simulé pour développer et démontrer sans AWS | `tools/mock-appsync/` |

Couvert par lot :
1. **Socle** : ingestion (API, import CSV, saisie, app) avec mapping par connecteur, normalisation (adresses, téléphones y compris DOM), défauts du client, géocodage, file d'anomalies, donnée brute conservée ; colis à code signé ; profils de preuve en cascade ; tournées dédiées ou mutualisées, collecte avant livraison, heures limites strictes, gel après démarrage ; historique non modifiable ; vue client cloisonnée côté serveur.
2. **Course à la demande** : prix selon la taille, le délai (1, 2 ou 3 jours) et les km, avec minimum, suppléments, code promo ; grille historisée ; paiement Stripe avant prise en charge ; remboursement si annulation ou échec ; suivi par étapes.
3. **Étiquettes et preuves** : étiquettes PDF 10 × 15 cm (QR + Code 128), étiquettes en réserve, modes strict / souple, envoi automatique B2B ; preuves exigées au point (scan, photo, signature, position, code), écart de position, commentaires prédéfinis.
4. **Rémunération** : grille au km par type de client et jour / nuit, historisée ; répartition en tournée mutualisée ; forfaits et minimum ; validation, relevé mensuel, export CSV.

Pas encore fait : portage des écrans V1 dans le back-office React, optimisation multi-tournées et insertion automatique (phases V2 / V3 de la spec), secteurs dessinés, carte live, forfaits B2B, rapports PDF automatiques, notifications push, documents d'onboarding des livreurs.

### Tests

```bash
cd mobile/amplify/backend/function/deliveryApi && (cd test/sdk && npm install) && (cd src && npm install) && node --test test/*.test.js
```
```bash
cd backoffice-react && npm install && npm test
```
```bash
cd mobile && flutter test test/platform_contract_test.dart
```

Les fichiers `mobile/test/fixtures/*.json` sont des réponses réelles de `deliveryApi` (`node tools/mock-appsync/export-fixtures.js mobile/test/fixtures`) : le test de contrat échoue si le format change.

### Mise en service (d'abord sur l'environnement `dev`)

1. **Fusionner le schéma avec celui de la production** : le schéma de l'archive V1 n'est pas à jour (l'app appelle `invokeLambdaRapportTournee`, absent). Récupérer le schéma déployé (`amplify pull`) et y reporter la partie plateforme avant tout `amplify push`.
2. **Paramètres de la fonction `deliveryApi`** dans `amplify/team-provider-info.json` : `graphqlApiId` (la valeur `dev` reprend celle de la Lambda V1 `createTournee`), `storageBucket` (bucket S3 du stockage), `senderEmail` (adresse SES vérifiée).
3. **Secrets dans SSM Parameter Store** (SecureString) : `/wabap/<env>/STRIPE_SECRET_KEY`, `/wabap/<env>/GOOGLE_MAPS_API_KEY` (Geocoding et Routes activés), `/wabap/<env>/LABEL_SIGNING_SECRET` (chaîne aléatoire longue : elle signe les codes des étiquettes, ne jamais la changer après la mise en service).
4. **Groupes Cognito** : `dispatch` et `finance` sont ajoutés ; y placer les dispatchers et comptables.
5. **Configuration initiale** dans le back-office : types de client, clients (l'identifiant = attribut `custom:clientName` de leurs utilisateurs), profils de preuve, commentaires prédéfinis, grille des courses, grille de rémunération.
6. `amplify push` sur `dev`, puis l'app :
   ```bash
   flutter run --dart-define=GOOGLE_MAPS_API_KEY=... --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

### Avant l'ouverture au public

- Conditions générales de vente, mentions RGPD (géolocalisation, données des destinataires, durée de conservation des preuves et des traces GPS), contrat des livreurs indépendants.
- Webhooks Stripe pour le rapprochement des paiements et remboursements.
- Imprimantes d'étiquettes : 203 dpi minimum (QR et code-barres relus à cette résolution).

### Points relevés dans la V1

- Les Lambda V1 tournent sous Node.js 16 : AWS ne permettra plus de les mettre à jour après le 31 août 2027.
- Le transformer Amplify signale que, sur plusieurs modèles V1 (Tournee, Inscription, Colis…), un propriétaire peut réattribuer la propriété d'un enregistrement (par exemple un livreur peut modifier le champ livreur d'une tournée). Des règles d'autorisation par champ corrigeraient ce point.
- Les preuves photo de la V1 sont envoyées sur S3 en accès `guest` (lisibles par tous) ; la plateforme utilise `protected`.
- Le magasin de clés de signature Android présent dans l'archive (`android/FOa3VztdaNW8`) n'a pas été importé : il doit rester hors du dépôt.

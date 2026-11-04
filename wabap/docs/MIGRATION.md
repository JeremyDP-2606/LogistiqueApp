# Bascule d'Amplify vers l'API Node.js

Les données restent en place (tables DynamoDB, bucket S3, groupe d'utilisateurs Cognito) : la bascule ne déplace
aucune donnée. Elle remplace AppSync et les fonctions Lambda par le serveur `backend/`, puis publie les nouvelles
versions des applications. À faire d'abord sur l'environnement `dev`.

## 0. Protéger les ressources existantes

Le dossier `mobile/amplify` a été retiré du dépôt, mais les piles CloudFormation d'Amplify existent toujours dans AWS
et possèdent les tables, le bucket et le groupe d'utilisateurs.

- Ne **jamais** lancer `amplify delete` ni `amplify push` depuis une ancienne copie du projet.
- Activer la protection contre la suppression sur chaque table DynamoDB (et les sauvegardes à un instant donné, PITR).
- Plus tard, détacher les ressources des piles Amplify (politique `Retain` puis suppression de la pile), ou les y laisser.

## 1. Relever les valeurs de l'environnement

| Valeur | Où la trouver | Variable du serveur |
|---|---|---|
| Suffixe des tables (`-<apiId>-<env>`) | Console DynamoDB (ex. `Colis-nfdn7djf2fcbdjz44rvjidtaf4-prod`) | `DYNAMODB_TABLE_SUFFIX` |
| Groupe d'utilisateurs | Console Cognito (prod : `us-east-1_c5SbPwJEZ`) | `COGNITO_USER_POOL_ID` |
| Applications clientes (app, back-offices) | Cognito > Intégration de l'application | `COGNITO_CLIENT_IDS` |
| Bucket du stockage | Console S3 (`wabap-…-s3-tournee…-<env>`) | `S3_BUCKET` |
| Clés Google, RouteXL, Stripe, signature des étiquettes | gestionnaire de secrets | voir `backend/.env.example` |
| Destinataires des rapports d'import | anciennement dans le code des Lambda | `IMPORT_REPORT_EMAILS`, `IMPORT_ERROR_EMAILS` |
| Imports SFTP planifiés | événement des règles EventBridge de `importCSV` | `SFTP_IMPORTS` |

Vérifier que les tables et index correspondent au schéma :

```bash
cd backend && DYNAMODB_TABLE_SUFFIX=-<apiId>-<env> npm run tables:check
```

Les tables de la plateforme V2 (Order, Parcel, Tour…) n'ont jamais été déployées : `npm run tables:create` les crée.

## 2. Déployer le serveur en parallèle d'AppSync

Image Docker `backend/Dockerfile` (AWS App Runner, ECS ou tout hébergeur de conteneurs), avec le rôle IAM décrit dans
`backend/README.md` et un nom de domaine en HTTPS (ex. `api.wabap.fr`), WebSocket autorisé.

Pendant la transition, les anciennes applications (AppSync) et les nouvelles (serveur) écrivent dans les mêmes tables.
Les anciennes Lambda de flux DynamoDB et les règles EventBridge `Mission_*` restent actives ; pour éviter un double
traitement, démarrer le serveur avec :

```
V1_TRIGGERS=false
MISSION_SCHEDULER=false
```

## 3. Publier les nouvelles applications

- **Back-office React** et **back-office Vue V1** : `VITE_API_URL`, `VITE_COGNITO_USER_POOL_ID`, `VITE_COGNITO_CLIENT_ID`
  (modèles `.env.example`), puis `npm run build`.
- **App mobile** : `--dart-define=API_URL=https://api.wabap.fr/graphql --dart-define=COGNITO_USER_POOL_ID=… --dart-define=COGNITO_CLIENT_ID=…`
  (plus `GOOGLE_MAPS_API_KEY` et `STRIPE_PUBLISHABLE_KEY` comme avant). Les utilisateurs devront se reconnecter une fois
  (la session Amplify n'est pas reprise).
- Ajouter la règle CORS `PUT` du bucket S3 pour les origines des back-offices.

## 4. Couper Amplify

Quand plus aucune ancienne version de l'app n'est utilisée (version minimale imposée dans les stores) :

1. Désactiver les déclencheurs des Lambda `triggerColisStatus`, `triggerTournee`, `triggerMission`
   (Lambda > Configuration > Déclencheurs > désactiver le flux DynamoDB).
2. Supprimer les règles EventBridge `Mission_*` et les règles d'import SFTP.
3. Redémarrer le serveur avec `V1_TRIGGERS=true` et `MISSION_SCHEDULER=true`.
4. Supprimer l'API AppSync et les fonctions Lambda (en conservant tables, bucket et groupe d'utilisateurs).
5. Supprimer le pool d'identités Cognito (plus utilisé : aucun identifiant AWS dans les navigateurs).

## Points à vérifier avant la bascule

- **Schéma de production** : le dépôt ne contenait pas tout le schéma déployé. Ont été ajoutés d'après le code des
  applications : `Mission.deliveryChecking` (texte), `Tournee.deliveryChecking` (booléen), les statuts de colis
  `PICKED_UP` et `NOT_PICKED_UP_NOT_EXIST`, la mutation `invokeLambdaRapportTournee`. Comparer avec le schéma
  réellement déployé (console AppSync > Schéma) avant la mise en service.
- **Rapport de fin de tournée** : la Lambda d'origine n'est pas dans le dépôt ; `backend/src/v1/rapport.js` en est une
  reconstruction (récapitulatif par e-mail). À comparer avec la Lambda en production.
- **Groupe `admin`** : en V1, `admin` désigne aussi l'administrateur d'un client (avec `custom:clientName`). Les règles de
  la plateforme V2 donnent au groupe `admin` l'accès à toutes les données V2 : réserver ce groupe à l'équipe Wabap ou
  revoir ces règles avant d'ouvrir le back-office React aux administrateurs clients.
- **Corrections apportées en portant les Lambda** : l'import Excel ne plantait plus sur un index absent (`byNumabo`) ni
  sur des destinataires non définis, utilise le nombre de colis par défaut choisi et réabonne un point de vente revenu ;
  les coordonnées GPS importées sont enregistrées comme nombres ; le rattachement d'une mission sans abonnés retire
  les anciens abonnés ; la liste des utilisateurs n'est plus limitée à 50.
- `generateReport`, `usersLambda` et `setAllOwner` ne sont pas portées : les deux premières ne fonctionnaient pas et ne
  sont appelées nulle part, la troisième était une migration ponctuelle déjà passée.

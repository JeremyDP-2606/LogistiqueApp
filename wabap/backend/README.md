# API Wabap (Node.js)

Serveur unique de la plateforme : il remplace AWS Amplify (AppSync, fonctions Lambda, règles EventBridge,
flux DynamoDB). **Cognito, DynamoDB, S3 et SES sont conservés** : mêmes comptes utilisateurs, mêmes tables,
mêmes fichiers.

| Élément | Avant (Amplify) | Maintenant |
|---|---|---|
| API GraphQL | AppSync | `POST /graphql`, même API (mêmes requêtes, mêmes types d'entrée) |
| Temps réel | AppSync (WebSocket propriétaire) | `wss://…/graphql`, protocole standard `graphql-transport-ws` |
| Règles d'accès `@auth` | AppSync | `src/auth/rules.js` (groupes, propriétaire, utilisateurs connectés, champs protégés) |
| Logique métier (`deliveryApi`) | Lambda | `src/delivery/` |
| Triggers V1 (`triggerColisStatus`, `triggerTournee`, `triggerMission`) | Lambda sur flux DynamoDB | `src/v1/triggers.js` (après chaque écriture) |
| `createTournee`, imports CSV / Excel, `updateMissionSubscribersId`, `listUsers` | Lambda appelées depuis le navigateur | routes `/v1/...` (`src/v1/`) |
| Génération planifiée des tournées | règles EventBridge `Mission_<id>` | `src/scheduler.js` |
| Gestion des utilisateurs (back-office V1) | SDK AWS dans le navigateur | `/v1/admin/users` (droits vérifiés par le serveur) |
| Envoi des preuves | Amplify Storage | lien d'envoi temporaire S3 (`createUploadUrl`) |
| Schéma → API | transformer Amplify | `src/schema/compile.js` (même résultat, vérifié) |

## Démarrer

```bash
npm install
npm run demo          # données fictives en mémoire, jetons de démo : http://localhost:4000/graphql
npm test              # 65 tests
```

Avec DynamoDB local et l'image Docker : `docker compose up` à la racine de `wabap/`.

Production : image Docker (`Dockerfile`), configuration par variables d'environnement (modèle : `.env.example`).
Variables indispensables : `DYNAMODB_TABLE_SUFFIX`, `COGNITO_USER_POOL_ID`, `COGNITO_CLIENT_IDS`, `S3_BUCKET`,
`SENDER_EMAIL`, `LABEL_SIGNING_SECRET`, `GOOGLE_MAPS_API_KEY`, `ROUTEXL_AUTH`, `STRIPE_SECRET_KEY`.

Une seule instance doit exécuter les tâches planifiées (`SCHEDULER_ENABLED=false` sur les autres). Le temps réel
est diffusé en mémoire : pour plusieurs instances, prévoir un bus partagé (Redis) derrière `src/graphql/pubsub.js`,
ou des connexions WebSocket rattachées à une seule instance.

## Authentification

Les applications envoient le **jeton d'identité Cognito** (ID token) dans l'en-tête `Authorization` (et, pour le temps
réel, dans `connectionParams.Authorization`). Le serveur vérifie la signature, l'expiration, le groupe d'utilisateurs et
l'application cliente (`aws-jwt-verify`). Le jeton porte les groupes (`cognito:groups`) et l'attribut `custom:clientName`
utilisés par les règles d'accès.

`AUTH_MODE=dev` accepte des jetons non signés : développement et démonstration seulement (refusé si `NODE_ENV=production`).

## Modifier le schéma

1. Modifier `schema/schema.graphql` (mêmes directives qu'avant : `@model`, `@auth`, `@index`, `@hasMany`…).
2. `npm run schema` : met à jour `schema/api.graphql`, l'API publiée (le test échoue s'il n'est pas à jour).
3. `npm run tables:check` puis `npm run tables:create` : crée les tables et index manquants.
4. `npm test` : vérifie aussi que toutes les requêtes des trois applications restent valides.

Une opération métier se déclare dans `type Query` / `type Mutation` du schéma et s'implémente dans
`src/delivery/index.js` (`OPERATIONS`).

## Droits AWS du serveur (rôle IAM)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan"],
      "Resource": ["arn:aws:dynamodb:us-east-1:<compte>:table/*-<apiId>-<env>", "arn:aws:dynamodb:us-east-1:<compte>:table/*-<apiId>-<env>/index/*"] },
    { "Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject"], "Resource": "arn:aws:s3:::<bucket>/*" },
    { "Effect": "Allow", "Action": ["ses:SendRawEmail", "ses:SendEmail"], "Resource": "*" },
    { "Effect": "Allow", "Action": ["cognito-idp:ListUsers", "cognito-idp:AdminGetUser", "cognito-idp:AdminCreateUser", "cognito-idp:AdminUpdateUserAttributes",
      "cognito-idp:AdminDeleteUser", "cognito-idp:AdminAddUserToGroup", "cognito-idp:AdminRemoveUserFromGroup", "cognito-idp:AdminListGroupsForUser"],
      "Resource": "arn:aws:cognito-idp:us-east-1:<compte>:userpool/<poolId>" }
  ]
}
```

Les scripts `tables:create` demandent en plus `dynamodb:CreateTable`, `dynamodb:DescribeTable`, `dynamodb:UpdateTable`.
Le bucket S3 doit autoriser les envois directs depuis les applications (règle CORS `PUT` pour les origines des back-offices ;
l'app mobile n'est pas concernée).

## Organisation

```
schema/schema.graphql     modèles et opérations (source)
schema/api.graphql        API publiée (générée)
src/server.js             démarrage (HTTP, WebSocket, tâches planifiées)
src/app.js                routes HTTP, GraphQL, WebSocket, fichiers locaux
src/schema/compile.js     schéma → API + métadonnées (index, relations, règles)
src/graphql/              résolveurs génériques, filtres, scalaires, temps réel, opérations du serveur
src/auth/                 jetons Cognito, règles d'accès
src/data/                 DynamoDB, mémoire, réactions après écriture
src/delivery/             logique métier de la plateforme (ex-deliveryApi)
src/v1/                   fonctions V1 (tournées, imports, utilisateurs, rapport)
scripts/                  tables DynamoDB, API publiée, données de démonstration, fixtures de l'app
```

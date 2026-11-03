# AppSync simulé (outil de développement)

Sert à développer et démontrer le back-office et l'app sans compte AWS.

- `appsync-schema.graphql` : schéma généré par le transformer Amplify à partir de `mobile/amplify/backend/api/wabap/schema.graphql` (à régénérer quand le schéma change).
- Les opérations de la fonction `deliveryApi` sont exécutées par son vrai code, sur un stockage en mémoire.
- `seed.js` crée un scénario en Martinique (clients fictifs) en passant par la logique métier.
- Les règles d'accès d'AppSync ne sont pas reproduites : l'outil teste les écrans, pas la sécurité.

```bash
npm install && node server.js     # http://localhost:4200/graphql
```

L'identité est lue dans l'en-tête `Authorization` (jeton JWT, non vérifié). Les fichiers générés (étiquettes PDF) sont servis sur `http://localhost:4200/fichiers/…`.

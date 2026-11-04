# Back-office Wabap (React)

Back-office de la plateforme (spec fonctionnelle v0.1), connecté à l'API Wabap (`../backend`) avec les comptes Cognito de l'app mobile.
L'ancien back-office Vue (`../backoffice`) reste utilisé pour les écrans V1 (missions, abonnés) en attendant leur portage.

| Rôle (groupe Cognito) | Écrans |
|---|---|
| `dispatch`, `admin`, `wabap` | Tableau de bord, demandes et file d'anomalies, import CSV, tournées (création, insertion, ordre, verrouillage, affectation, étiquettes, clôture) |
| `finance`, `admin`, `wabap` | Rémunération : tournées à valider, ajustements motivés, relevés mensuels, export CSV |
| `admin`, `wabap` | Clients et types de client, profils de preuve, commentaires prédéfinis, tarifs des courses (avec simulateur), grilles de rémunération |
| `client` | Ses demandes et leur suivi |

```bash
npm install
npm run dev        # http://localhost:5174
npm test           # le calcul de prix du simulateur est identique à celui du serveur
```

Configuration (`.env.local` / `.env.production`, modèle `.env.example`) : `VITE_API_URL` (adresse de l'API),
`VITE_COGNITO_USER_POOL_ID`, `VITE_COGNITO_CLIENT_ID`. La connexion passe par le SDK Cognito (`amazon-cognito-identity-js`) ;
aucun identifiant AWS n'est utilisé dans le navigateur.

## Développer sans AWS

`cd ../backend && npm run demo` démarre l'API sur un scénario de démonstration (données fictives, jetons non signés acceptés).

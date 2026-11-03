# Back-office Wabap (React)

Back-office de la plateforme (spec fonctionnelle v0.1), connecté au même AWS Amplify / Cognito que l'app mobile.
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
npm test           # le calcul de prix du simulateur est identique à celui de la Lambda
```

`src/aws-exports.js` vient de la configuration Amplify (`amplify pull`). Le pool d'identités n'est volontairement pas utilisé : le back-office ne parle qu'à AppSync avec le jeton Cognito.

## Développer sans AWS

`../tools/mock-appsync` simule AppSync avec le schéma réellement généré et la vraie fonction `deliveryApi`, sur un scénario de démonstration.

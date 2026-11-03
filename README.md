# LogistiqueApp

Plateforme de livraison urbaine du dernier kilomètre : des clients (commerces, particuliers) commandent une course, des coursiers indépendants la réalisent, et tout se suit en temps réel.

| Dossier     | Techno                          | Rôle |
|-------------|---------------------------------|------|
| `backend/`  | Node.js · Express · Socket.IO   | API REST, authentification JWT, tarification, dispatch et temps réel |
| `frontend/` | React · Vite · Leaflet          | Espace client web (commande, suivi) et console d'administration |
| `mobile/`   | Flutter                         | Application mobile unique : mode **client** ou **coursier** selon le compte |

## Fonctionnalités

**Client** (web et mobile)
- Création de compte et connexion
- Recherche d'adresse avec autocomplétion, ou position actuelle (mobile)
- Devis immédiat selon la distance, la taille du colis (S/M/L/XL) et le délai (standard ou express), avec choix du véhicule
- Commande, puis suivi en direct : statuts, position du coursier sur la carte, appel du coursier
- **Code de remise à 4 chiffres** que le destinataire donne au coursier pour valider la livraison
- Annulation (tant que le colis n'est pas récupéré), historique, notation du coursier

**Coursier** (mobile)
- Inscription avec son véhicule (vélo, scooter, voiture, utilitaire)
- Passage en ligne ou hors ligne, envoi de la position GPS en continu
- Réception en temps réel des courses proches (rayon de 15 km, véhicule adapté), acceptation
- Déroulé guidé : vers le retrait → colis récupéré → en livraison → validation par code ; signalement d'échec avec motif
- Itinéraire GPS externe, appel des contacts
- Gains du jour, de la semaine et totaux, note moyenne

**Admin** (web)
- Indicateurs : courses, chiffre d'affaires, rémunération des coursiers, utilisateurs
- Carte de la flotte en ligne, statut des coursiers, liste de toutes les courses

## Démarrage rapide

### 1. Backend
```bash
cd backend
npm install
npm run seed      # comptes de démonstration
npm run dev       # http://localhost:4000
```
Comptes de démo (mot de passe `demo1234`) : `admin@demo.fr`, `client@demo.fr`, `velo@demo.fr`, `scooter@demo.fr`, `voiture@demo.fr`, `van@demo.fr`.

Variables d'environnement : voir `backend/.env.example` (`JWT_SECRET`, `PORT`, `DB_FILE`, `CORS_ORIGIN`).

### 2. Front web
```bash
cd frontend
npm install
npm run dev       # http://localhost:5173 (proxy vers l'API sur :4000)
```

### 3. Application mobile
```bash
cd mobile
flutter pub get
# Émulateur Android (10.0.2.2 = machine hôte) :
flutter run
# Téléphone physique : indiquer l'IP de la machine qui fait tourner l'API
flutter run --dart-define=API_URL=http://192.168.1.20:4000
```

## Tests
```bash
cd backend && npm test        # parcours complet API et temps réel
cd mobile && flutter test     # modèles
cd mobile && flutter analyze
```

## API (résumé)

| Méthode | Route | Rôle |
|---|---|---|
| POST | `/api/auth/register`, `/api/auth/login` | tous |
| GET/PATCH | `/api/auth/me` | connecté |
| GET | `/api/catalog` | public |
| POST | `/api/quotes` | connecté |
| POST/GET | `/api/jobs` | client (création) ; liste filtrée selon le rôle |
| GET | `/api/jobs/:id` | parties prenantes |
| POST | `/api/jobs/:id/cancel`, `/api/jobs/:id/rate` | client |
| PATCH | `/api/courier/status` | coursier |
| POST | `/api/courier/location` | coursier |
| GET | `/api/courier/jobs/available`, `/api/courier/jobs/current`, `/api/courier/earnings` | coursier |
| POST | `/api/courier/jobs/:id/accept`, `/api/courier/jobs/:id/status` | coursier |
| GET | `/api/admin/stats`, `/api/admin/users`, `/api/admin/couriers/live` | admin |
| GET | `/api/geo/search`, `/api/geo/reverse` | connecté |

**Temps réel (Socket.IO, token dans `auth.token`)**
- Serveur → client : `job:new` (aux coursiers éligibles), `job:taken`, `job:updated`, `courier:location`
- Client → serveur : `job:subscribe`, `job:unsubscribe`, `courier:location`

Cycle de vie d'une course : `pending → assigned → picking_up → picked_up → delivering → delivered`, avec en plus `cancelled` (avant le retrait) et `failed` (pendant la livraison).

## Pour la production
- Remplacer le stockage JSON (`backend/src/db.js`) par PostgreSQL ou MongoDB : tout l'accès aux données passe par ce module.
- Utiliser un géocodeur et un serveur de tuiles commerciaux : les services publics OpenStreetMap ont des limites d'usage.
- Ajouter le paiement (Stripe, par exemple), les notifications push (FCM/APNs), l'envoi du code de remise par SMS, et la localisation en arrière-plan pour les coursiers.
- Définir un `JWT_SECRET` fort et restreindre `CORS_ORIGIN`.

# Démo vidéo Wabap V2

Tournage automatisé de la démonstration commerciale : app cliente, app livreur et back-office côte à côte,
sur le serveur Wabap en mode démonstration (vraie logique métier, données fictives en mémoire).

1. Serveur : `cd backend && npm install && npm run demo` (port 4000, scénario neuf à chaque démarrage)
2. App Flutter de démo (web) :
   ```
   cd mobile
   flutter build web -t lib/main_demo.dart --no-web-resources-cdn --dart-define=GOOGLE_MAPS_API_KEY=demo --output build/web-demo
   ```
   puis servir `build/web-demo` sur les ports 8081 (cliente) et 8082 (livreur) ; l'adresse de l'API est passée
   dans l'URL (`?persona=client&api=http://localhost:4000/graphql`, fait par `record.js`).
3. Back-office : `cd backoffice-react && VITE_API_URL=http://localhost:4000/graphql npx vite build --outDir /tmp/bo && npx vite preview --outDir /tmp/bo --port 5174`
4. `node demo/record.js --shots` (captures de mise au point) ou `node demo/record.js` (vidéo WebM + `out/chapters.json`) ;
   `DEBUG=1` affiche les erreurs du navigateur.
5. Conversion : `ffmpeg -i out/page@*.webm -c:v libx264 -preset slow -crf 27 -pix_fmt yuv420p -r 25 -movflags +faststart -an wabap-demo.mp4`

`page.template.html` est la page de partage (chapitres et vignettes injectés depuis `out/chapters.json`).
Les services externes (Google Places, Stripe, appareil photo, scanner) sont simulés par `mobile/lib/v2/demo_hooks.dart`,
le serveur en mode démonstration et `record.js`.

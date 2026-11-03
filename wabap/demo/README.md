# Démo vidéo Wabap V2

Tournage automatisé de la démonstration commerciale : app cliente, app livreur et back-office côte à côte,
sur l'AppSync simulé (`tools/mock-appsync`, vraie logique de la fonction deliveryApi, données fictives).

1. AppSync simulé : `cd tools/mock-appsync && npm install && node server.js` (port 4200, scénario neuf à chaque démarrage)
2. App Flutter de démo (web) :
   ```
   cd mobile
   cp ../demo/pubspec_overrides.demo.yaml pubspec_overrides.yaml && flutter pub get
   flutter build web -t lib/main_demo.dart --no-web-resources-cdn --dart-define=GOOGLE_MAPS_API_KEY=demo --output build/web-demo
   rm pubspec_overrides.yaml && git checkout pubspec.lock && flutter pub get
   ```
   puis servir `build/web-demo` sur les ports 8081 (cliente) et 8082 (livreur).
3. Back-office : `cd backoffice-react && npm run dev -- --port 5174`
4. `node demo/record.js --shots` (captures de mise au point) ou `node demo/record.js` (vidéo WebM + `out/chapters.json`)
5. Conversion : `ffmpeg -i out/page@*.webm -c:v libx264 -preset slow -crf 27 -pix_fmt yuv420p -r 25 -movflags +faststart -an wabap-demo.mp4`

`page.template.html` est la page de partage (chapitres et vignettes injectés depuis `out/chapters.json`).
Les API externes (Google Places, Stripe, appareil photo, scanner) sont simulées par `lib/v2/demo_hooks.dart` et `record.js`.

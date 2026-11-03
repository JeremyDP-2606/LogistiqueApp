# Vidéo de démonstration

`record.js` filme automatiquement le parcours complet. La scène (`stage.html`) montre côte à côte l'app mobile client, l'app mobile coursier (deux instances de l'app Flutter compilée pour le web) et le site React.

Parcours filmé : la coursière passe en ligne → le client commande (adresses, colis, express, devis) → la course arrive en temps réel → acceptation → déplacement GPS suivi en direct → remise avec le code à 4 chiffres → notation → gains du coursier → console admin.

## Régénérer la vidéo

Il faut Node.js, Flutter, Playwright (avec Chromium) et ffmpeg. Chaque serveur ci-dessous tourne en continu : lancez-les dans des terminaux séparés.

1. Compiler l'app mobile pour le web :
```bash
cd mobile
flutter build web --no-web-resources-cdn --dart-define=API_URL=http://localhost:4000
```

2. Lancer l'API sur une base de démo neuve (depuis la racine du dépôt) :
```bash
cd backend && rm -f data/db.json && npm run seed && npm start
```

3. Servir l'app mobile deux fois, sur deux ports différents, pour que le client et le coursier aient chacun leur session :
```bash
cd mobile/build/web && python3 -m http.server 8081
```
```bash
cd mobile/build/web && python3 -m http.server 8082
```

4. Lancer le site web :
```bash
cd frontend && npx vite --port 5173
```

5. Filmer, puis convertir en MP4 :
```bash
node demo/record.js demo-output
```
```bash
ffmpeg -i demo-output/*.webm -c:v libx264 -crf 23 -pix_fmt yuv420p -movflags +faststart demo-output/LogistiqueApp-demo.mp4
```

L'option `--debug` remplace la vidéo par une capture d'écran à chaque étape.

## Ce qui est simulé

Le reste (API, temps réel, apps) tourne pour de vrai. Seuls ces éléments sont simulés :
- **Les tuiles de carte** : elles sont remplacées par un fond de plan neutre (`assets/tile.png`). La vidéo a été tournée dans un environnement sans accès à OpenStreetMap.
- **La recherche d'adresse** : elle renvoie une liste fixe de vraies adresses parisiennes avec leurs coordonnées.
- **Le GPS du coursier** : la position est émulée par Playwright le long du trajet.

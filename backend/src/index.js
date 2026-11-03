const fs = require('fs');
const path = require('path');

// Chargement simple d'un fichier .env (sans dépendance)
const envFile = path.join(__dirname, '..', '.env');
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
  }
}

const { createApp } = require('./app');
const { server, db } = createApp();
const port = Number(process.env.PORT) || 4000;

server.listen(port, () => console.log(`API LogistiqueApp sur http://localhost:${port}`));

const shutdown = () => { db.flush(); process.exit(0); };
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

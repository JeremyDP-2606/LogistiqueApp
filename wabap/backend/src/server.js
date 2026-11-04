// Démarrage du serveur : HTTP + WebSocket, tâches planifiées, arrêt propre.
const http = require('http');
const { loadConfig } = require('./config');
const { createServices } = require('./services');
const { createApp } = require('./app');
const { createScheduler } = require('./scheduler');

async function start(env = process.env) {
  const config = loadConfig(env);
  // Démonstration : données fictives (Martinique) en mémoire, géocodage et paiement simulés,
  // jetons de démo « demo-client » et « demo-livreur » pour l'app mobile de démonstration
  const demo = env.DEMO_SEED === 'true';
  if (demo && (config.store !== 'memory' || config.authMode !== 'dev')) throw new Error('DEMO_SEED exige STORE=memory et AUTH_MODE=dev');
  const seed = demo ? require('../scripts/demo-seed') : null;
  const services = createServices(config, demo ? { google: seed.geocoder, router: null, stripe: seed.stripe, personas: seed.personas } : {});
  if (demo) services.log.log(await seed.run(services.delivery, services.store));
  const { app, attachWebSocket } = createApp(services);
  await services.auth.warmUp().catch((e) => services.log.warn(`Clés Cognito non préchargées : ${e.message}`));

  const server = http.createServer(app);
  const ws = attachWebSocket(server);
  const scheduler = config.schedulerEnabled ? createScheduler(services) : null;
  if (scheduler) await scheduler.start();

  await new Promise((resolve) => server.listen(config.port, resolve));
  services.log.log(`API Wabap : ${config.publicUrl}/graphql (données : ${config.store}${config.tableSuffix ? ` *${config.tableSuffix}` : ''}, auth : ${config.authMode}, tâches planifiées : ${scheduler ? 'oui' : 'non'})`);

  const stop = async () => {
    services.log.log('Arrêt du serveur…');
    scheduler?.stop();
    await ws.close();
    await new Promise((r) => server.close(r));
    await services.store.drain();
    process.exit(0);
  };
  process.once('SIGTERM', stop);
  process.once('SIGINT', stop);
  return { server, services, stop };
}

if (require.main === module) {
  start().catch((e) => { console.error(e.message); process.exit(1); });
}

module.exports = { start };

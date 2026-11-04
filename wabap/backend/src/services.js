// Assemblage des services du serveur à partir de la configuration (dépendances injectables pour les tests).
const fs = require('fs');
const path = require('path');
const { compileSchema } = require('./schema/compile');
const { createMemoryStore } = require('./data/memory');
const { createDynamoStore } = require('./data/dynamo');
const { withStreams } = require('./data/streams');
const { createS3Files, createLocalFiles } = require('./files');
const { createSesMailer, createConsoleMailer } = require('./mailer');
const { createCognitoAuth, createDevAuth } = require('./auth/cognito');
const { createPubSub } = require('./graphql/pubsub');
const { createResolvers } = require('./graphql/resolvers');
const { createServerOperations } = require('./graphql/serverOperations');
const { buildServices, OPERATIONS, UserError } = require('./delivery');
const { createGoogle } = require('./delivery/lib/google');
const { createStripe } = require('./delivery/lib/stripe');
const { createV1 } = require('./v1');

const SCHEMA_FILE = path.join(__dirname, '../schema/schema.graphql');

function createServices(config, overrides = {}) {
  const log = overrides.log || console;
  const compiled = overrides.compiled || compileSchema(fs.readFileSync(SCHEMA_FILE, 'utf8'));

  const indexes = Object.fromEntries(Object.values(compiled.models).map((m) => [m.name, Object.fromEntries(m.indexes.map((i) => [i.name, i]))]));
  const baseStore = overrides.store || (config.store === 'memory'
    ? createMemoryStore({ indexes })
    : createDynamoStore({ tableSuffix: config.tableSuffix, region: config.region, endpoint: config.dynamoEndpoint }));
  const store = withStreams(baseStore, { log });

  const files = overrides.files || (config.bucket
    ? createS3Files({ bucket: config.bucket, region: config.region, endpoint: config.s3Endpoint })
    : createLocalFiles({ dir: path.resolve(config.filesDir), publicUrl: () => config.publicUrl }));
  const mailer = overrides.mailer || (config.senderEmail ? createSesMailer({ region: config.region, from: config.senderEmail, files }) : createConsoleMailer({ log }));
  const google = overrides.google !== undefined ? overrides.google
    : config.googleMapsKey ? createGoogle({ getKey: async () => config.googleMapsKey }) : null;
  const stripe = overrides.stripe !== undefined ? overrides.stripe
    : config.stripeKey ? createStripe({ getKey: async () => config.stripeKey }) : null;

  const delivery = buildServices({
    store,
    geocoder: google,
    router: overrides.router !== undefined ? overrides.router : google,
    stripe,
    labelSecret: config.labelSecret || 'secret-de-developpement',
    files,
    mailer,
    config: config.business,
    log,
    ...(overrides.now ? { now: overrides.now } : {}),
  });

  // Opérations métier : erreurs fonctionnelles transmises, erreurs internes masquées
  async function business(name, identity, args) {
    const op = OPERATIONS[name];
    if (!op) throw new Error(`Opération inconnue : ${name}`);
    try {
      return await op(delivery, identity, args || {});
    } catch (e) {
      if (e instanceof UserError) throw e;
      log.error(`${name} :`, e);
      throw new Error('Erreur serveur, réessayez dans un instant');
    }
  }

  const pubsub = createPubSub();
  const v1 = createV1({ store, files, mailer, config, google, log, fetchImpl: overrides.fetchImpl });
  const schema = createResolvers({ compiled, store, pubsub, business, serverOps: createServerOperations({ files }), log });
  const auth = overrides.auth || (config.authMode === 'dev'
    ? createDevAuth({ personas: overrides.personas })
    : createCognitoAuth({ userPoolId: config.userPoolId, clientIds: config.clientIds }));

  return { config, log, compiled, store, files, mailer, delivery, business, pubsub, schema, auth, v1 };
}

module.exports = { createServices, SCHEMA_FILE };

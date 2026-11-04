// Application HTTP : API GraphQL (POST /graphql), temps réel (WebSocket /graphql, protocole graphql-ws),
// routes REST des fonctions V1 (/v1/...), fichiers locaux en développement (/files/...).
const express = require('express');
const { parse, validate, execute, specifiedRules, GraphQLError } = require('graphql');
const { WebSocketServer } = require('ws');
const { useServer } = require('graphql-ws/lib/use/ws');

// Erreurs au format de l'API historique : { message, errorType, path, locations }
function formatError(e) {
  const original = e.originalError || e;
  const errorType = e.extensions?.errorType || original.errorType
    || (original.constructor?.name === 'UserError' ? 'Lambda:Handled' : e.path ? 'ExecutionError' : 'ValidationError');
  return { message: e.message, errorType, path: e.path, locations: e.locations };
}

const tokenOf = (req) => req.headers.authorization || req.headers['x-api-key'] || null;

function createApp(services) {
  const { schema, auth, config, log } = services;
  const app = express();
  app.disable('x-powered-by');

  // CORS : origines autorisées (CORS_ORIGINS), toutes en développement si non renseigné
  app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin && (!config.corsOrigins.length || config.corsOrigins.includes(origin))) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Headers', req.headers['access-control-request-headers'] || 'authorization, content-type');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.setHeader('Access-Control-Max-Age', '600');
    }
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    return next();
  });

  app.get('/health', (req, res) => res.json({ ok: true }));

  // Identité de l'appelant (jeton Cognito vérifié), null si absente
  async function identify(req) {
    const token = tokenOf(req);
    if (!token) return null;
    try { return await auth.identify(token); } catch (e) {
      const err = new Error(`Jeton invalide : ${e.message}`);
      err.status = 401;
      throw err;
    }
  }

  async function runGraphQL({ query, variables, operationName }, identity) {
    let document;
    try { document = parse(query); } catch (e) { return { errors: [formatError(e)] }; }
    const errors = validate(schema, document, specifiedRules);
    if (errors.length) return { errors: errors.map(formatError) };
    const result = await execute({ schema, document, variableValues: variables, operationName, contextValue: { identity, services } });
    if (result.errors) {
      for (const e of result.errors) if (e.originalError && !e.originalError.errorType && e.originalError.constructor?.name !== 'UserError') log.warn?.(`[GraphQL] ${e.path?.join('.') || ''} : ${e.message}`);
      return { data: result.data, errors: result.errors.map(formatError) };
    }
    return { data: result.data };
  }

  app.post('/graphql', express.json({ limit: config.bodyLimit }), async (req, res) => {
    try {
      const identity = await identify(req);
      if (!identity) return res.status(401).json({ errors: [{ errorType: 'UnauthorizedException', message: 'Jeton absent' }] });
      if (!req.body || typeof req.body.query !== 'string') return res.status(400).json({ errors: [{ errorType: 'BadRequest', message: 'Requête GraphQL attendue' }] });
      return res.json(await runGraphQL(req.body, identity));
    } catch (e) {
      if (e.status === 401) return res.status(401).json({ errors: [{ errorType: 'UnauthorizedException', message: e.message }] });
      log.error(e);
      return res.status(500).json({ errors: [{ errorType: 'InternalError', message: 'Erreur serveur' }] });
    }
  });

  // Routes REST protégées (fonctions V1)
  const router = express.Router();
  router.use(express.json({ limit: config.bodyLimit }));
  router.use(async (req, res, next) => {
    try {
      req.identity = await identify(req);
      if (!req.identity) return res.status(401).json({ error: 'Jeton absent' });
      return next();
    } catch (e) { return res.status(401).json({ error: e.message }); }
  });
  services.v1.routes(router);
  app.use('/v1', router);

  // Fichiers locaux (développement, sans S3)
  if (services.files.receive) {
    app.put('/files/upload/:token', express.raw({ type: '*/*', limit: '20mb' }), async (req, res) => {
      const key = await services.files.receive(req.params.token, req.body);
      return key ? res.json({ key }) : res.status(403).json({ error: 'Lien expiré' });
    });
    app.get('/files/:key', (req, res) => {
      try { return res.sendFile(services.files.path(decodeURIComponent(req.params.key))); } catch { return res.sendStatus(404); }
    });
  }

  app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
    if (err.type === 'entity.too.large') return res.status(413).json({ error: 'Contenu trop volumineux' });
    log.error(err);
    return res.status(500).json({ error: 'Erreur serveur' });
  });

  // Temps réel : abonnements GraphQL sur WebSocket (sous-protocole graphql-transport-ws)
  function attachWebSocket(httpServer) {
    const wss = new WebSocketServer({ server: httpServer, path: '/graphql' });
    const cleanup = useServer({
      schema,
      context: async (ctx) => ({ identity: ctx.extra.identity, services }),
      onConnect: async (ctx) => {
        const p = ctx.connectionParams || {};
        const token = p.Authorization || p.authorization || p.token;
        try {
          ctx.extra.identity = await auth.identify(token);
          return Boolean(ctx.extra.identity);
        } catch { return false; }
      },
      onError: (ctx, msg, errors) => errors.map((e) => new GraphQLError(formatError(e).message)),
    }, wss);
    return { wss, close: () => cleanup.dispose() };
  }

  return { app, attachWebSocket, runGraphQL };
}

module.exports = { createApp, formatError };

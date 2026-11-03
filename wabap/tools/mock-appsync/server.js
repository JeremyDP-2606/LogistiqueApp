// AppSync SIMULÉ pour le développement et les démonstrations (jamais déployé).
// - Schéma : celui réellement généré par le transformer Amplify (appsync-schema.graphql), donc toute
//   requête du back-office ou de l'app qui ne correspond pas au schéma échoue ici aussi.
// - Opérations @function : exécutées par le vrai code de la fonction deliveryApi.
// - Requêtes générées (get, list, index, relations, création de configuration) : stockage en mémoire.
// Les règles d'accès d'AppSync ne sont PAS reproduites : cet outil teste les écrans, pas la sécurité.
//
//   npm install && node server.js        → http://localhost:4200/graphql
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { buildSchema, graphql } = require('graphql');

const FN = path.join(__dirname, '../../mobile/amplify/backend/function/deliveryApi');
const { handle, buildServices, OPERATIONS } = require(path.join(FN, 'src/index'));
const { createMemoryStore } = require(path.join(FN, 'test/memoryStore'));
const { renderLabels } = require(path.join(FN, 'src/lib/labelPdf'));
const seed = require('./seed');

const PORT = Number(process.env.PORT) || 4200;
const SOURCE_SCHEMA = fs.readFileSync(path.join(__dirname, '../../mobile/amplify/backend/api/wabap/schema.graphql'), 'utf8');

const schema = buildSchema(`
  scalar AWSDate
  scalar AWSDateTime
  scalar AWSJSON
  directive @aws_subscribe(mutations: [String]) on FIELD_DEFINITION
  directive @aws_cognito_user_pools(cognito_groups: [String]) on FIELD_DEFINITION | OBJECT
  directive @aws_iam on FIELD_DEFINITION | OBJECT
  ${fs.readFileSync(path.join(__dirname, 'appsync-schema.graphql'), 'utf8')}
`);

// ---------- Index et relations déclarés dans le schéma source ----------
const models = {};
for (const m of SOURCE_SCHEMA.matchAll(/^type (\w+) @model[^{]*\{([\s\S]*?)\n\}/gm)) {
  const [, name, body] = m;
  const indexes = [];
  const relations = [];
  for (const line of body.split('\n')) {
    const field = line.trim().match(/^(\w+):/)?.[1];
    for (const ix of line.matchAll(/@index\(name: "(\w+)"(?:, queryField: "(\w+)")?(?:, sortKeyFields: \["(\w+)"\])?\)/g)) {
      indexes.push({ name: ix[1], queryField: ix[2], key: field, sortKey: ix[3] });
    }
    const rel = line.match(/^\s*(\w+): \[(\w+)\] @hasMany\(indexName: "(\w+)"/);
    if (rel) relations.push({ field: rel[1], child: rel[2], index: rel[3] });
  }
  models[name] = { indexes, relations };
}
const plural = (n) => (n.endsWith('s') ? n : n.endsWith('y') ? `${n.slice(0, -1)}ies` : `${n}s`);

// ---------- Services réels sur un stockage en mémoire ----------
const store = createMemoryStore();
const files = new Map();
const services = buildServices({
  store,
  labelSecret: 'secret-de-demo',
  geocoder: seed.geocoder,
  router: null,
  stripe: seed.stripe,
  files: {
    async put(key, bytes) { files.set(key, bytes); return { key, url: `http://localhost:${PORT}/fichiers/${encodeURIComponent(key)}` }; },
    async get(key) { return files.get(key); },
  },
  mailer: { async send(m) { console.log(`[e-mail simulé] ${m.to.join(', ')} : ${m.subject}`); } },
  config: { tzOffsetMinutes: -240 },
  log: { warn() {}, error: console.error, log() {} },
});

// Profils de l'app de démonstration (authentification par clé d'API simulée)
const API_KEY_PERSONAS = {
  'demo-client': { sub: 'part-demo', groups: [], claims: { email: 'jessica@exemple.fr', given_name: 'Jessica' } },
  'demo-livreur': { sub: 'livreur-lea', groups: ['livreur'], claims: { email: 'lea@exemple.fr', given_name: 'Léa Marie-Sainte' } },
};

function identityFrom(headers) {
  if (API_KEY_PERSONAS[headers['x-api-key']]) return API_KEY_PERSONAS[headers['x-api-key']];
  const auth = headers.authorization;
  if (!auth) return null;
  try {
    const p = JSON.parse(Buffer.from(auth.replace(/^Bearer /, '').split('.')[1], 'base64url').toString());
    return { sub: p.sub, groups: p['cognito:groups'] || [], claims: p };
  } catch { return null; }
}

const matches = (item, filter) => !filter || Object.entries(filter).every(([k, cond]) => {
  if (k === 'and') return cond.every((f) => matches(item, f));
  if (k === 'or') return cond.some((f) => matches(item, f));
  if (cond.eq !== undefined) return item[k] === cond.eq;
  if (cond.ne !== undefined) return item[k] !== cond.ne;
  if (cond.contains !== undefined) return String(item[k] || '').includes(cond.contains);
  return true;
});

// Relations @hasMany : renvoient une connexion { items, nextToken }
function withRelations(model, item) {
  if (!item) return item;
  const out = { ...item };
  for (const r of models[model]?.relations || []) {
    const ix = models[r.child].indexes.find((x) => x.name === r.index);
    out[r.field] = async () => {
      const items = await store.query(r.child, r.index, ix.key, item.id);
      if (ix.sortKey) items.sort((a, b) => String(a[ix.sortKey]).localeCompare(String(b[ix.sortKey]), 'fr', { numeric: true }));
      return { items: items.map((x) => withRelations(r.child, x)), nextToken: null };
    };
  }
  return out;
}

function rootFor(identity) {
  const root = {};
  const event = (fieldName, args) => ({ fieldName, arguments: args, identity: { sub: identity.sub, groups: identity.groups, claims: identity.claims } });
  for (const [model, def] of Object.entries(models)) {
    root[`get${model}`] = async ({ id }) => withRelations(model, await store.get(model, id));
    root[`list${plural(model)}`] = async ({ filter }) => ({
      items: [...(store.tables[model]?.values() || [])].filter((x) => matches(x, filter)).map((x) => withRelations(model, x)), nextToken: null,
    });
    // Nom explicite (queryField) ou nom automatique d'Amplify : <modèles>By<Clé>And<Tri>
    const cap = (x) => x[0].toUpperCase() + x.slice(1);
    for (const ix of def.indexes) {
      ix.queryField = ix.queryField || `${plural(model)[0].toLowerCase()}${plural(model).slice(1)}By${cap(ix.key)}${ix.sortKey ? `And${cap(ix.sortKey)}` : ''}`;
    }
    for (const ix of def.indexes) {
      root[ix.queryField] = async (args) => {
        const items = (await store.query(model, ix.name, ix.key, args[ix.key])).filter((x) => matches(x, args.filter));
        if (ix.sortKey) items.sort((a, b) => String(a[ix.sortKey]).localeCompare(String(b[ix.sortKey])) * (args.sortDirection === 'DESC' ? -1 : 1));
        return { items: items.slice(0, args.limit || 1000).map((x) => withRelations(model, x)), nextToken: null };
      };
    }
    root[`create${model}`] = async ({ input }) => {
      const at = new Date().toISOString();
      return store.put(model, { __typename: model, id: input.id || crypto.randomUUID(), ...input, createdAt: at, updatedAt: at });
    };
    root[`update${model}`] = async ({ input }) => store.update(model, input.id, { ...input, updatedAt: new Date().toISOString() });
    root[`delete${model}`] = async ({ input }) => { const x = await store.get(model, input.id); await store.delete(model, input.id); return x; };
  }
  // Opérations métier en dernier : elles priment sur les noms génériques (ex. updateCourierPosition)
  for (const op of Object.keys(OPERATIONS)) root[op] = (args) => handle(event(op, args), services);
  return root;
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Headers', req.headers['access-control-request-headers'] || '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
  if (req.method === 'GET' && req.url.startsWith('/fichiers/')) {
    const bytes = files.get(decodeURIComponent(req.url.slice('/fichiers/'.length)));
    if (!bytes) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': 'application/pdf' });
    return res.end(Buffer.from(bytes));
  }
  let body = '';
  req.on('data', (c) => (body += c));
  req.on('end', async () => {
    res.setHeader('Content-Type', 'application/json');
    const identity = identityFrom(req.headers);
    if (!identity) { res.writeHead(401); return res.end(JSON.stringify({ errors: [{ errorType: 'UnauthorizedException', message: 'Jeton absent' }] })); }
    const { query, variables } = JSON.parse(body);
    const result = await graphql({ schema, source: query, rootValue: rootFor(identity), variableValues: variables });
    if (result.errors) {
      result.errors = result.errors.map((e) => ({ message: e.message, errorType: 'Lambda:Handled', path: e.path }));
      console.log(`[GraphQL] ${result.errors.map((e) => `${(e.path || []).join('.')} : ${e.message}`).join(' | ')}`);
    }
    res.end(JSON.stringify(result));
  });
});

seed.run(services, store).then((summary) => {
  server.listen(PORT, () => console.log(`AppSync simulé : http://localhost:${PORT}/graphql\n${summary}`));
});

module.exports = { renderLabels };

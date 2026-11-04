// Serveur de test : stockage en mémoire, authentification de développement, e-mails et fichiers simulés.
const os = require('os');
const path = require('path');
const fs = require('fs');
const { loadConfig } = require('../src/config');
const { createServices } = require('../src/services');
const { createApp } = require('../src/app');

function identity(sub, { groups = [], clientName, username } = {}) {
  const claims = { sub, 'cognito:username': username || sub, 'cognito:groups': groups, given_name: sub };
  if (clientName) claims['custom:clientName'] = clientName;
  return { sub, username: username || sub, groups, claims };
}

const PEOPLE = {
  wabap: identity('wabap-1', { groups: ['wabap'] }),
  admin: identity('admin-1', { groups: ['admin'] }),
  dispatch: identity('dispatch-1', { groups: ['dispatch'] }),
  finance: identity('finance-1', { groups: ['finance'] }),
  livreur: identity('livreur-1', { groups: ['livreur'] }),
  livreur2: identity('livreur-2', { groups: ['livreur'] }),
  fa: identity('client-fa', { clientName: 'France-Antilles' }),
  autre: identity('client-autre', { clientName: 'Autre' }),
  particulier: identity('part-1'),
};

function testServer(env = {}, overrides = {}) {
  const filesDir = fs.mkdtempSync(path.join(os.tmpdir(), 'wabap-files-'));
  const quiet = { log() {}, warn() {}, error() {} };
  const config = loadConfig({ STORE: 'memory', AUTH_MODE: 'dev', SCHEDULER_ENABLED: 'false', FILES_DIR: filesDir, ...env });
  const services = createServices(config, { log: quiet, google: null, stripe: null, ...overrides });
  const { app, attachWebSocket, runGraphQL } = createApp(services);
  const gql = async (who, query, variables) => runGraphQL({ query, variables }, typeof who === 'string' ? PEOPLE[who] : who);
  // Échec si erreur GraphQL
  const ok = async (who, query, variables) => {
    const r = await gql(who, query, variables);
    if (r.errors) throw new Error(r.errors.map((e) => e.message).join(' | '));
    return r.data;
  };
  return { services, app, attachWebSocket, gql, ok, store: services.store, config };
}

// Jeton de développement (JWT non signé, accepté uniquement en AUTH_MODE=dev)
const devToken = (who) => {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  return `${b64({ alg: 'none' })}.${b64({ ...PEOPLE[who].claims, exp: Math.floor(Date.now() / 1000) + 3600 })}.x`;
};

module.exports = { testServer, identity, PEOPLE, devToken };

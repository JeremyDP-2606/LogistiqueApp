// Bout en bout : HTTP (POST /graphql, routes /v1), temps réel (WebSocket graphql-ws), fichiers locaux.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const WebSocket = require('ws');
const { createClient } = require('graphql-ws');
const { testServer, devToken } = require('./helpers');

async function listen(env) {
  const t = testServer(env);
  const server = http.createServer(t.app);
  const ws = t.attachWebSocket(server);
  await new Promise((r) => server.listen(0, r));
  const base = `http://127.0.0.1:${server.address().port}`;
  t.services.config.publicUrl = base;
  const close = async () => { await ws.close(); await new Promise((r) => server.close(r)); };
  return { ...t, base, close };
}

const post = (base, who, query, variables) => fetch(`${base}/graphql`, {
  method: 'POST',
  headers: { 'content-type': 'application/json', ...(who ? { authorization: devToken(who) } : {}) },
  body: JSON.stringify({ query, variables }),
});

test('HTTP : jeton exigé, requête GraphQL, CORS', async () => {
  const s = await listen({ CORS_ORIGINS: 'https://backoffice.wabap.fr' });
  try {
    assert.equal((await post(s.base, null, '{ listMissions { items { id } } }')).status, 401);
    const bad = await fetch(`${s.base}/graphql`, { method: 'POST', headers: { 'content-type': 'application/json', authorization: 'pas-un-jeton' }, body: '{"query":"{ __typename }"}' });
    assert.equal(bad.status, 401);
    const r = await post(s.base, 'wabap', 'mutation { createMission(input: { owner: "FA", name: "A", livreurID: "l", startLongitude: 0, startLatitude: 0 }) { name } }');
    assert.deepEqual(await r.json(), { data: { createMission: { name: 'A' } } });
    const invalid = await (await post(s.base, 'wabap', '{ champInconnu }')).json();
    assert.equal(invalid.errors[0].errorType, 'ValidationError');
    const pre = await fetch(`${s.base}/graphql`, { method: 'OPTIONS', headers: { origin: 'https://backoffice.wabap.fr', 'access-control-request-headers': 'authorization,content-type' } });
    assert.equal(pre.status, 204);
    assert.equal(pre.headers.get('access-control-allow-origin'), 'https://backoffice.wabap.fr');
    const foreign = await fetch(`${s.base}/health`, { headers: { origin: 'https://ailleurs.example' } });
    assert.equal(foreign.headers.get('access-control-allow-origin'), null);
  } finally { await s.close(); }
});

test('temps réel : abonnement WebSocket authentifié reçoit les créations', async () => {
  const s = await listen();
  const client = createClient({ url: `${s.base.replace('http', 'ws')}/graphql`, webSocketImpl: WebSocket, connectionParams: { Authorization: devToken('wabap') }, retryAttempts: 0 });
  try {
    const received = new Promise((resolve, reject) => {
      client.subscribe({ query: 'subscription { onCreateMission { name } }' }, { next: resolve, error: reject, complete: () => {} });
    });
    // laisser l'abonnement s'établir
    for (let i = 0; i < 50 && s.services.pubsub.count() === 0; i++) await new Promise((r) => setTimeout(r, 20));
    await post(s.base, 'wabap', 'mutation { createMission(input: { owner: "FA", name: "Temps réel", livreurID: "l", startLongitude: 0, startLatitude: 0 }) { id } }');
    assert.equal((await received).data.onCreateMission.name, 'Temps réel');
    // Connexion sans jeton refusée
    const anon = createClient({ url: `${s.base.replace('http', 'ws')}/graphql`, webSocketImpl: WebSocket, retryAttempts: 0, lazy: false });
    const refused = await new Promise((resolve) => {
      anon.on('closed', (e) => resolve(e.code));
    });
    assert.equal(refused, 4403);
    await anon.dispose();
  } finally { await client.dispose(); await s.close(); }
});

test('routes V1 : contrôle d\'accès et rattachement des abonnés', async () => {
  const s = await listen();
  try {
    await s.store.put('Mission', { id: 'M1', owner: 'France-Antilles', name: 'A', livreurID: 'l' });
    await s.store.put('Subscriber', { id: 'a', owner: 'France-Antilles', name: 'a', nb: 1, type: 'subscriber' });
    const call = (who, method, path, body) => fetch(`${s.base}/v1${path}`, { method, headers: { 'content-type': 'application/json', ...(who ? { authorization: devToken(who) } : {}) }, body: body && JSON.stringify(body) });
    assert.equal((await call(null, 'GET', '/users')).status, 401);
    assert.equal((await call('fa', 'GET', '/users')).status, 403);
    assert.equal((await call('autre', 'PUT', '/missions/M1/subscribers', { subscriberIds: ['a'] })).status, 403);
    const ok = await call('fa', 'PUT', '/missions/M1/subscribers', { subscriberIds: ['a'] });
    assert.deepEqual(await ok.json(), { removed: 0, added: 1 });
    assert.equal((await s.store.get('Subscriber', 'a')).missionSubscribersId, 'M1');
    assert.equal((await call('fa', 'PUT', '/missions/inconnue/subscribers', { subscriberIds: ['a'] })).status, 404);
    assert.equal((await call('autre', 'POST', '/imports/csv', { clientName: 'France-Antilles', data: 'x' })).status, 403);
  } finally { await s.close(); }
});

test('preuves : lien d\'envoi temporaire puis dépôt du fichier (stockage local)', async () => {
  const s = await listen();
  try {
    const r = await (await post(s.base, 'livreur', 'mutation { createUploadUrl(kind: "photo", contentType: "image/png", tourId: "T1") }')).json();
    const up = JSON.parse(r.data.createUploadUrl);
    assert.match(up.key, /^proofs\/livreur-1\/T1\/photo-.+\.png$/);
    const put = await fetch(up.url, { method: 'PUT', headers: up.headers, body: Buffer.from([1, 2, 3]) });
    assert.equal(put.status, 200);
    assert.deepEqual([...await s.services.files.get(up.key)], [1, 2, 3]);
    assert.equal((await fetch(up.url, { method: 'PUT', body: 'x' })).status, 403); // lien à usage unique
    const refused = await (await post(s.base, 'fa', 'mutation { createUploadUrl(kind: "photo", contentType: "image/png") }')).json();
    assert.equal(refused.errors[0].errorType, 'Unauthorized');
  } finally { await s.close(); }
});

test('utilisateurs Cognito : un administrateur client ne gère que les comptes de son entreprise', async () => {
  const users = [
    { Username: 'fa-livreur', Attributes: [{ Name: 'sub', Value: 's1' }, { Name: 'custom:clientName', Value: 'France-Antilles' }] },
    { Username: 'autre-livreur', Attributes: [{ Name: 'sub', Value: 's2' }, { Name: 'custom:clientName', Value: 'Autre' }] },
  ];
  const sent = [];
  const cognitoClient = {
    async send(cmd) {
      const name = cmd.constructor.name;
      sent.push([name, cmd.input]);
      if (name === 'ListUsersCommand') return { Users: cmd.input.Filter ? users.filter((u) => cmd.input.Filter.includes(u.Attributes[0].Value)) : users };
      if (name === 'AdminGetUserCommand') { const u = users.find((x) => x.Username === cmd.input.Username); return { Username: u.Username, UserAttributes: u.Attributes }; }
      return {};
    },
  };
  const { identity } = require('./helpers');
  const t = testServer({ COGNITO_USER_POOL_ID: 'us-east-1_test' }, { cognitoClient });
  const server = http.createServer(t.app);
  await new Promise((r) => server.listen(0, r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const tok = (who) => `${b64({})}.${b64({ ...who.claims, exp: Math.floor(Date.now() / 1000) + 600 })}.x`;
  const clientFA = identity('chef-fa', { groups: ['admin'], clientName: 'France-Antilles' });
  const controleur = identity('ctrl-fa', { groups: ['client'], clientName: 'France-Antilles' });
  const call = (who, method, path, body) => fetch(`${base}/v1${path}`, { method, headers: { 'content-type': 'application/json', authorization: tok(who) }, body: body && JSON.stringify(body) });
  try {
    const list = await (await call(clientFA, 'GET', '/admin/users')).json();
    assert.deepEqual(list.map((u) => u.Username), ['fa-livreur']);
    assert.equal((await call(clientFA, 'DELETE', '/admin/users/autre-livreur')).status, 403);
    assert.equal((await call(clientFA, 'POST', '/admin/users', { username: 'x', email: 'x@y.z', password: 'Motdepasse1', group: 'wabap' })).status, 403);
    assert.equal((await call(controleur, 'GET', '/admin/users')).status, 200); // consultation seule
    assert.equal((await call(controleur, 'DELETE', '/admin/users/fa-livreur')).status, 403);
    assert.equal((await call(clientFA, 'POST', '/admin/users', { username: 'x', email: 'x@y.z', password: 'Motdepasse1', group: 'livreur', clientName: 'Autre' })).status, 200);
    const created = sent.find(([n]) => n === 'AdminCreateUserCommand')[1];
    assert.equal(created.UserAttributes.find((a) => a.Name === 'custom:clientName').Value, 'France-Antilles'); // imposé
    assert.equal(created.UserPoolId, 'us-east-1_test');
    const livreur = identity('liv', { groups: ['livreur'] });
    assert.equal((await call(livreur, 'GET', '/admin/users')).status, 403);
    const staff = await (await call(identity('w', { groups: ['wabap'] }), 'GET', '/admin/users')).json();
    assert.equal(staff.length, 2);
  } finally { await new Promise((r) => server.close(r)); }
});

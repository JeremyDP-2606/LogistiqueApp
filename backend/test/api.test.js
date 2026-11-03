const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { io: ioClient } = require('socket.io-client');
const { createApp } = require('../src/app');
const pricing = require('../src/pricing');

let ctx, base;
const PICKUP = { address: '10 rue de Rivoli, Paris', lat: 48.8556, lng: 2.3601, contactName: 'Boutique', phone: '0102030405' };
const DROPOFF = { address: '5 avenue de l’Opéra, Paris', lat: 48.8650, lng: 2.3340, contactName: 'Alice', phone: '0607080910' };

async function call(method, path, body, token) {
  const res = await fetch(base + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: await res.json() };
}

before(async () => {
  ctx = createApp({ dbFile: ':memory:' });
  await new Promise((r) => ctx.server.listen(0, r));
  base = `http://localhost:${ctx.server.address().port}/api`;
});
after(() => { ctx.io.close(); ctx.server.close(); });

test('tarification : options triées et contraintes véhicule/taille', () => {
  const q = pricing.quote({ pickup: PICKUP, dropoff: DROPOFF, packageSize: 'L' });
  assert.ok(q.distanceKm > 1 && q.distanceKm < 5);
  assert.deepEqual(q.options.map((o) => o.vehicle), ['car', 'van']);
  const exp = pricing.quote({ pickup: PICKUP, dropoff: DROPOFF, urgency: 'express' }).options[0];
  const std = pricing.quote({ pickup: PICKUP, dropoff: DROPOFF }).options[0];
  assert.ok(exp.price.ttc > std.price.ttc);
  assert.equal(std.price.ttc, pricing.round2(std.price.ht + std.price.tva));
});

test('parcours complet : commande, dispatch temps réel, livraison avec code, notation', async () => {
  const client = (await call('POST', '/auth/register', { name: 'Client', email: 'c@t.fr', password: 'secret1' })).body;
  const courier = (await call('POST', '/auth/register', { name: 'Coursier', email: 'k@t.fr', password: 'secret1', role: 'courier', vehicle: 'bike' })).body;
  assert.ok(client.token && courier.token);
  assert.equal(client.user.passwordHash, undefined);

  // doublon
  assert.equal((await call('POST', '/auth/register', { name: 'X', email: 'C@t.fr', password: 'secret1' })).status, 409);

  await call('PATCH', '/courier/status', { online: true }, courier.token);
  await call('POST', '/courier/location', { lat: 48.857, lng: 2.355 }, courier.token);

  const sock = ioClient(base.replace('/api', ''), { auth: { token: courier.token }, transports: ['websocket'] });
  await new Promise((r) => sock.on('connect', r));
  const gotNew = new Promise((r) => sock.on('job:new', r));

  const q = await call('POST', '/quotes', { pickup: PICKUP, dropoff: DROPOFF, packageSize: 'S' }, client.token);
  assert.equal(q.status, 200);
  assert.equal(q.body.options[0].vehicle, 'bike');

  const created = await call('POST', '/jobs', { pickup: PICKUP, dropoff: DROPOFF, packageSize: 'S', vehicle: 'bike' }, client.token);
  assert.equal(created.status, 201);
  const job = created.body.job;
  assert.match(job.ref, /^LG-\d{6}$/);
  assert.match(job.deliveryCode, /^\d{4}$/);

  const evt = await gotNew;
  assert.equal(evt.job.id, job.id);
  assert.equal(evt.job.deliveryCode, undefined, 'le coursier ne doit pas voir le code');
  sock.close();

  const avail = await call('GET', '/courier/jobs/available', null, courier.token);
  assert.equal(avail.body.jobs.length, 1);

  // le client s'abonne au suivi
  const csock = ioClient(base.replace('/api', ''), { auth: { token: client.token }, transports: ['websocket'] });
  await new Promise((r) => csock.on('connect', r));
  const sub = await new Promise((r) => csock.emit('job:subscribe', job.id, r));
  assert.equal(sub.ok, true);
  const gotLoc = new Promise((r) => csock.on('courier:location', r));

  assert.equal((await call('POST', `/courier/jobs/${job.id}/accept`, {}, courier.token)).body.job.status, 'assigned');
  await call('POST', '/courier/location', { lat: 48.856, lng: 2.359 }, courier.token);
  assert.equal((await gotLoc).jobId, job.id);
  csock.close();

  // transition invalide
  assert.equal((await call('POST', `/courier/jobs/${job.id}/status`, { status: 'delivered', code: job.deliveryCode }, courier.token)).status, 409);
  for (const s of ['picking_up', 'picked_up', 'delivering']) {
    assert.equal((await call('POST', `/courier/jobs/${job.id}/status`, { status: s }, courier.token)).body.job.status, s);
  }
  assert.equal((await call('POST', `/courier/jobs/${job.id}/status`, { status: 'delivered', code: '9999' === job.deliveryCode ? '0000' : '9999' }, courier.token)).status, 400);
  const done = await call('POST', `/courier/jobs/${job.id}/status`, { status: 'delivered', code: job.deliveryCode }, courier.token);
  assert.equal(done.body.job.status, 'delivered');
  assert.equal(done.body.job.history.length, 6);

  const rated = await call('POST', `/jobs/${job.id}/rate`, { stars: 4 }, client.token);
  assert.equal(rated.body.job.rating.stars, 4);

  const earn = await call('GET', '/courier/earnings', null, courier.token);
  assert.equal(earn.body.total.count, 1);
  assert.equal(earn.body.rating, 4);
});

test('annulation et contrôle d’accès', async () => {
  const a = (await call('POST', '/auth/register', { name: 'A', email: 'a@t.fr', password: 'secret1' })).body;
  const b = (await call('POST', '/auth/register', { name: 'B', email: 'b@t.fr', password: 'secret1' })).body;
  const job = (await call('POST', '/jobs', { pickup: PICKUP, dropoff: DROPOFF }, a.token)).body.job;
  assert.equal((await call('GET', `/jobs/${job.id}`, null, b.token)).status, 404);
  assert.equal((await call('POST', `/jobs/${job.id}/cancel`, {}, b.token)).status, 404);
  assert.equal((await call('POST', `/jobs/${job.id}/cancel`, {}, a.token)).body.job.status, 'cancelled');
  assert.equal((await call('POST', `/jobs/${job.id}/cancel`, {}, a.token)).status, 409);
  assert.equal((await call('GET', '/admin/stats', null, a.token)).status, 403);
  assert.equal((await call('GET', '/jobs', null)).status, 401);
});

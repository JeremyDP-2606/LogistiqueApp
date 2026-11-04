// Lot 3 : étiquettes PDF, réserve, envoi automatique B2B cloisonné, statistiques des commentaires.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryStore } = require('./memoryStore');
const { createOrders } = require('../../src/delivery/lib/orders');
const { createTours } = require('../../src/delivery/lib/tours');
const { createLabels } = require('../../src/delivery/lib/labelsService');
const { encodeCode, decodeCode, customerTag } = require('../../src/delivery/lib/labels');

const admin = { sub: 'admin', groups: ['admin'] };
const courier = { sub: 'livreur-1', groups: ['livreur'] };
const ens = { sub: 'u-ens', groups: ['client'], clientName: 'ENSEIGNE' };
const gar = { sub: 'u-gar', groups: ['client'], clientName: 'GARAGE' };
const pt = (lat, lng, name) => ({ formatted: name, street: name, latitude: lat, longitude: lng, postalCode: '97200' });

async function setup(now = '2026-11-04T10:00:00Z') {
  const store = createMemoryStore();
  const files = new Map();
  const mails = [];
  let clock = new Date(now);
  const ctx = {
    store, labelSecret: 's', now: () => clock,
    files: { async put(key, bytes) { files.set(key, bytes); return { key, url: `https://fichiers/${key}` }; } },
    mailer: { async send(m) { mails.push(m); } },
  };
  const orders = createOrders(ctx);
  const tours = createTours(ctx, orders);
  const labels = createLabels(ctx, orders);
  await store.put('Customer', { id: 'ENSEIGNE', name: 'Enseigne Caraïbes', billingMode: 'ACCOUNT', labelEmail: { enabled: true, emails: ['logistique@enseigne.fr'], leadHours: 24 } });
  await store.put('Customer', { id: 'GARAGE', name: 'Garage', billingMode: 'ACCOUNT', labelEmail: { enabled: true, emails: ['garage@exemple.fr'], leadHours: 6 } });
  await store.put('Customer', { id: 'IND-p', name: 'Particulier', billingMode: 'PER_ORDER', labelEmail: { enabled: true, emails: ['p@exemple.fr'] } });
  await store.put('CommentPreset', { id: 'gardien', kind: 'DELIVERY', label: 'Laissé au gardien', clientVisible: true, active: 'yes' });
  const mk = (cid, n) => orders.ingest(admin, { customerId: cid, source: 'MANUAL', record: {
    pickupAddress: pt(14.61, -61.03, 'Entrepôt'), deliveryAddress: pt(14.60 + n / 1000, -61.07, `Rue ${n}`), deliveryName: `Client ${n}`, parcelCount: 2,
  } });
  const o1 = await mk('ENSEIGNE', 1);
  const o2 = await mk('GARAGE', 2);
  const tour = await tours.createTour(admin, { date: '2026-11-05', startTime: '2026-11-05T08:00:00.000Z', start: { latitude: 14.61, longitude: -61.05 }, courierId: courier.sub });
  await tours.addOrders(admin, { tourId: tour.id, orderIds: [o1.id, o2.id] });
  return { store, files, mails, orders, tours, labels, o1, o2, tour, setClock: (d) => { clock = new Date(d); } };
}

test('code signé : empreinte client, falsification détectée', () => {
  const c = encodeCode('s', 'ABC123', 'ENSEIGNE');
  assert.deepEqual(decodeCode('s', c), { parcelId: 'ABC123', customerTag: customerTag('ENSEIGNE') });
  assert.match(decodeCode('autre-secret', c).error, /signature/);
  assert.match(decodeCode('s', c.replace('ABC123', 'ABC124')).error, /signature/);
  assert.match(decodeCode('s', '3017620422003').error, /non reconnue/, 'code-barres propre au client refusé');
  assert.notEqual(customerTag('ENSEIGNE'), customerTag('GARAGE'));
});

test('génération manuelle : PDF de la tournée, étiquettes en réserve, cloisonnement client', async () => {
  const env = await setup();
  const all = await env.labels.generate(admin, { tourId: env.tour.id });
  assert.equal(all.count, 4);
  const pdf = env.files.get(all.key);
  assert.equal(Buffer.from(pdf.slice(0, 5)).toString(), '%PDF-');
  // Le client Enseigne n'obtient que ses étiquettes, même dans une tournée mutualisée
  const mine = await env.labels.generate(ens, { tourId: env.tour.id });
  assert.equal(mine.count, 2);
  await assert.rejects(env.labels.generate(ens, { orderId: env.o2.id }), /introuvable/);
  // 20 étiquettes en réserve en plus (ex. 250 étiquettes pour 20 colis réels)
  const extra = await env.labels.generate(admin, { tourId: env.tour.id, customerId: 'ENSEIGNE', extraCount: 20 });
  assert.equal(extra.reservedCount, 20);
  assert.equal(extra.count, 22);
  await assert.rejects(env.labels.generate(admin, { tourId: env.tour.id, extraCount: 5 }), /Précisez le client/);
  const ev = await env.orders.history(env.o1.parcels[0].id);
  assert.ok(ev.some((e) => e.type === 'LABEL_GENERATED'));
});

test('envoi automatique B2B : selon le délai du client, cloisonné, complément seulement pour les ajouts', async () => {
  const env = await setup('2026-11-04T07:00:00Z'); // tournée le 05/11 à 08:00 UTC
  assert.deepEqual(await env.labels.sendDue(), [], 'trop tôt pour les deux clients');
  env.setClock('2026-11-04T08:30:00Z'); // < 24 h avant : Enseigne seulement (Garage : 6 h)
  let sent = await env.labels.sendDue();
  assert.deepEqual(sent.map((s) => [s.customerId, s.count, s.complement]), [['ENSEIGNE', 2, false]]);
  assert.deepEqual(env.mails[0].to, ['logistique@enseigne.fr']);
  assert.match(env.mails[0].subject, /^Étiquettes – tournée du 2026-11-05 \(2 colis\)/);
  assert.deepEqual(await env.labels.sendDue(), [], 'pas de renvoi');

  // Un colis ajouté à la tournée après l'envoi : envoi complémentaire avec la seule nouvelle étiquette
  const o3 = await env.orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'MANUAL', record: {
    pickupAddress: pt(14.61, -61.03, 'Entrepôt'), deliveryAddress: pt(14.605, -61.07, 'Rue 3'), deliveryName: 'Client 3', parcelCount: 1,
  } });
  await env.tours.addOrders(admin, { tourId: env.tour.id, orderIds: [o3.id] });
  sent = await env.labels.sendDue();
  assert.deepEqual(sent.map((s) => [s.customerId, s.count, s.complement]), [['ENSEIGNE', 1, true]]);
  assert.match(env.mails[1].subject, /complémentaires/);

  env.setClock('2026-11-05T02:30:00Z');
  sent = await env.labels.sendDue();
  assert.deepEqual(sent.map((s) => s.customerId), ['GARAGE']);
  assert.deepEqual(env.mails.at(-1).to, ['garage@exemple.fr']);
  const evs = await env.orders.history(env.o2.parcels[0].id);
  assert.ok(evs.some((e) => e.type === 'LABEL_SENT'));
});

test('clients à la course : jamais d’envoi automatique', async () => {
  const env = await setup('2026-11-05T07:00:00Z');
  const o = await env.orders.ingest({ sub: 'p', groups: [] }, { source: 'CLIENT_APP', record: {
    pickupAddress: pt(14.61, -61.03, 'A'), deliveryAddress: pt(14.62, -61.07, 'B'), deliveryName: 'X',
  } });
  await env.tours.addOrders(admin, { tourId: env.tour.id, orderIds: [o.id] });
  const sent = await env.labels.sendDue();
  assert.ok(!sent.some((s) => s.customerId === 'IND-p'));
});

test('statistiques des commentaires prédéfinis par motif et code postal', async () => {
  const env = await setup();
  await env.tours.start(courier, { tourId: env.tour.id });
  const stops = await env.tours.stopsOf(env.tour.id);
  for (const s of stops.filter((x) => x.type === 'PICKUP')) await env.tours.submitStop(courier, { stopId: s.id });
  for (const s of stops.filter((x) => x.type === 'DELIVERY')) await env.tours.submitStop(courier, { stopId: s.id, comment: { presetId: 'gardien' } });
  const stats = await env.labels.commentStats(admin, { from: '2026-11-04', to: '2026-11-04' });
  assert.deepEqual(stats.map((s) => [s.label, s.postalCode, s.count]), [['Laissé au gardien', '97200', 4]]);
  await assert.rejects(env.labels.commentStats(ens, { from: '2026-11-04', to: '2026-11-04' }), /équipes Wabap/);
});

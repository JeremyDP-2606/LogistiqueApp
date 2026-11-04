// Lot 1 : demandes, colis, points, tournées, preuves, historique, cloisonnement.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryStore } = require('./memoryStore');
const { createOrders } = require('../../src/delivery/lib/orders');
const { createTours } = require('../../src/delivery/lib/tours');
const { encodeCode } = require('../../src/delivery/lib/labels');
const N = require('../../src/delivery/lib/normalize');
const P = require('../../src/delivery/lib/proofs');

const SECRET = 'secret-de-test';
// Géocodeur factice : adresses connues de Fort-de-France
const PLACES = {
  'zone de la jambette': { latitude: 14.6160, longitude: -61.0300, postalCode: '97232', city: 'Le Lamentin' },
  'rue victor hugo': { latitude: 14.6037, longitude: -61.0731, postalCode: '97200', city: 'Fort-de-France' },
  'route de didier': { latitude: 14.6280, longitude: -61.0800, postalCode: '97200', city: 'Fort-de-France' },
  'boulevard du général de gaulle': { latitude: 14.6070, longitude: -61.0680, postalCode: '97200', city: 'Fort-de-France' },
  'rue lamartine': { latitude: 14.6050, longitude: -61.0700, postalCode: '97200', city: 'Fort-de-France' },
};
const geocoder = {
  async geocode(q) {
    const key = Object.keys(PLACES).find((k) => q.toLowerCase().includes(k));
    return key ? { ...PLACES[key], formatted: q, quality: 'ROOFTOP' } : null;
  },
};

const admin = { sub: 'admin-1', groups: ['admin'] };
const courier = { sub: 'livreur-1', groups: ['livreur'] };
const enseigne = { sub: 'u-ens', groups: ['client'], clientName: 'ENSEIGNE' };
const garage = { sub: 'u-gar', groups: ['client'], clientName: 'GARAGE' };

async function setup({ config } = {}) {
  const store = createMemoryStore();
  const ctx = { store, geocoder, labelSecret: SECRET, config, now: () => new Date('2026-11-04T05:00:00Z') };
  const orders = createOrders(ctx);
  const tours = createTours(ctx, orders);
  // Configuration : profils de preuve, types de client, clients, commentaires prédéfinis
  await store.put('ProofProfile', { id: 'standard', name: 'Standard', pickup: { scan: true }, delivery: { geoloc: true, photo: true } });
  await store.put('ProofProfile', { id: 'securise', name: 'Sécurisé', pickup: { scan: true }, delivery: { scan: true, signature: true, geoloc: true } });
  await store.put('CustomerType', { id: 'grand-compte', name: 'Grand compte', proofProfileId: 'standard' });
  await store.put('Customer', {
    id: 'ENSEIGNE', name: 'Enseigne Caraïbes', customerTypeId: 'grand-compte', billingMode: 'ACCOUNT', labelMode: 'STRICT',
    defaults: JSON.stringify({ parcelCount: 2, size: 'M', pickupAddress: 'Zone de la Jambette, 97232 Le Lamentin', pickupName: 'Entrepôt Enseigne' }),
  });
  await store.put('Customer', { id: 'GARAGE', name: 'Garage Lamartine', customerTypeId: 'grand-compte', billingMode: 'ACCOUNT', labelMode: 'FLEXIBLE', proofProfileId: 'securise' });
  await store.put('Connector', {
    id: 'api-enseigne', customerId: 'ENSEIGNE', kind: 'API',
    mapping: JSON.stringify({ externalRef: 'num_commande', deliveryName: 'client', deliveryPhone: 'tel', deliveryAddress: ['numero', 'voie', 'cp', 'ville'], instructions: 'commentaire' }),
  });
  for (const [id, kind, label, clientVisible] of [
    ['gardien', 'DELIVERY', 'Laissé au gardien', true],
    ['absent', 'FAILURE', 'Destinataire absent', true],
    ['acces', 'DELIVERY', 'Accès difficile', false],
  ]) await store.put('CommentPreset', { id, kind, label, clientVisible, active: 'yes' });
  return { store, orders, tours };
}

const enseigneRecord = (ref, extra = {}) => ({
  num_commande: ref, client: 'JOSEPH MARIE-LINE', tel: '0696 11 22 33',
  numero: '12', voie: 'rue Victor Hugo', cp: '97200', ville: 'Fort-de-France', commentaire: '  2e étage  ', ...extra,
});

test('normalisation : téléphones des DOM, adresses découpées, noms et e-mails', () => {
  assert.equal(N.normalizePhone('0696 11 22 33'), '+596696112233');
  assert.equal(N.normalizePhone('0690112233'), '+590690112233');
  assert.equal(N.normalizePhone('06 12 34 56 78'), '+33612345678');
  assert.equal(N.normalizePhone('0262 11 22 33'), '+262262112233');
  assert.equal(N.normalizePhone('12'), null);
  assert.deepEqual(N.splitAddress('12 bis rue Victor Hugo, Bât. B, 97200 Fort-de-France'),
    { number: '12 bis', street: 'rue Victor Hugo', complement: 'Bât. B', postalCode: '97200', city: 'Fort-de-France', country: 'FR' });
  assert.equal(N.normalizeName('JOSEPH MARIE-LINE'), 'Joseph Marie-Line');
  assert.equal(N.normalizeEmail(' Marie@Exemple.FR '), 'marie@exemple.fr');
  assert.deepEqual(N.applyMapping({ a: '12', b: 'rue X', c: '' }, { address: ['a', 'b', 'c'] }), { address: '12 rue X' });
});

test('ingestion API : mapping du connecteur, défauts du client, géocodage, donnée brute conservée', async () => {
  const { orders, store } = await setup();
  const o = await orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne', record: enseigneRecord('CMD-1') });
  assert.equal(o.status, 'CREATED');
  assert.deepEqual(o.anomalies, []);
  assert.equal(o.externalRef, 'CMD-1');
  assert.equal(o.delivery.contact.name, 'Joseph Marie-Line');
  assert.equal(o.delivery.contact.phone, '+596696112233');
  assert.equal(o.delivery.address.number, '12');
  assert.equal(o.delivery.address.latitude, 14.6037);
  assert.equal(o.delivery.instructions, '2e étage');
  assert.equal(o.pickup.contact.name, 'Entrepôt Enseigne', 'collecte par défaut du client');
  assert.equal(o.parcelCount, 2, 'nombre de colis par défaut du client');
  assert.equal(o.size, 'M');
  assert.equal(JSON.parse(o.rawInput).num_commande, 'CMD-1');
  assert.equal(o.parcels.length, 2);
  assert.match(o.parcels[0].code, /^WB1\.[0-9A-Z]{6}\.[0-9A-Z]{6}\.[\w-]{10}$/);
  assert.ok(o.parcels[0].code.length <= 30, 'assez court pour un code-barres');
  assert.deepEqual([o.parcels[0].index, o.parcels[0].total], [1, 2]);
  const ev = await orders.history(o.parcels[0].id);
  assert.deepEqual(ev.map((e) => e.type), ['CREATED']);
  assert.equal((await store.get('Order', o.id)).customerId, 'ENSEIGNE');
});

test('file d’anomalies : adresse introuvable, téléphone invalide, doublon ; correction par le dispatcher', async () => {
  const { orders } = await setup();
  await orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne', record: enseigneRecord('CMD-2') });
  const bad = await orders.ingest(admin, {
    customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne',
    record: enseigneRecord('CMD-2', { voie: 'impasse inconnue', tel: '12' }),
  });
  assert.equal(bad.status, 'TO_FIX');
  assert.deepEqual(bad.anomalies.map((a) => a.code).sort(), ['ADDRESS_NOT_FOUND', 'DUPLICATE', 'INVALID_PHONE']);
  // Correction : adresse et téléphone corrigés, mais le doublon reste à confirmer
  let fixed = await orders.fix(admin, { orderId: bad.id, patch: { deliveryAddress: '5 rue Lamartine, 97200 Fort-de-France', deliveryPhone: '0696 44 55 66' } });
  assert.deepEqual(fixed.anomalies.map((a) => a.code), ['DUPLICATE']);
  fixed = await orders.fix(admin, { orderId: bad.id, patch: { confirmNotDuplicate: true } });
  assert.equal(fixed.status, 'CREATED');
  await assert.rejects(orders.fix(enseigne, { orderId: bad.id, patch: {} }), /équipes Wabap/);
});

test('cloisonnement à l’ingestion : un client ne crée pas de demande pour un autre', async () => {
  const { orders } = await setup();
  await assert.rejects(orders.ingest(garage, { customerId: 'ENSEIGNE', source: 'CLIENT_APP', record: {} }), /Accès refusé/);
  const o = await orders.ingest(garage, { source: 'CLIENT_APP', record: {
    pickupAddress: '5 rue Lamartine, 97200 Fort-de-France', deliveryAddress: 'Route de Didier, 97200 Fort-de-France', deliveryName: 'Client garage',
  } });
  assert.equal(o.customerId, 'GARAGE');
});

test('profils de preuve : cascade type → client → demande → colis, agrégation par point', () => {
  const t = { proofProfileId: 'standard' };
  assert.equal(P.resolveProfileId({ customerType: t, customer: {}, order: {}, parcel: {} }), 'standard');
  assert.equal(P.resolveProfileId({ customerType: t, customer: { proofProfileId: 'securise' }, order: {}, parcel: {} }), 'securise');
  assert.equal(P.resolveProfileId({ customerType: t, customer: { proofProfileId: 'securise' }, order: {}, parcel: { proofProfileId: 'haute' } }), 'haute');
  const agg = P.aggregateStop([
    { parcel: { id: 'a' }, profile: { delivery: { signature: true, scan: true } } },
    { parcel: { id: 'b' }, profile: { delivery: { photo: true } } },
  ], 'DELIVERY');
  assert.deepEqual(agg.perStop, { photo: true, signature: true, geoloc: false, otp: false });
  assert.deepEqual(agg.scanParcelIds, ['a'], 'scan colis par colis, signature une seule fois');
});

async function plannedTour(env) {
  const { orders, tours } = env;
  const o1 = await orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne', record: enseigneRecord('CMD-10') });
  const o2 = await orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne',
    record: enseigneRecord('CMD-11', { numero: '', voie: 'Route de Didier' }) });
  const o3 = await orders.ingest(admin, { customerId: 'GARAGE', source: 'MANUAL', record: {
    pickupAddress: '5 rue Lamartine, 97200 Fort-de-France', pickupName: 'Garage',
    deliveryAddress: 'Boulevard du Général de Gaulle, 97200 Fort-de-France', deliveryName: 'Atelier', deliveryPhone: '0696 77 88 99', parcelCount: 1,
  } });
  const tour = await tours.createTour(admin, { date: '2026-11-04', slot: 'NIGHT', start: { latitude: 14.6100, longitude: -61.0500 }, courierId: courier.sub });
  const planned = await tours.addOrders(admin, { tourId: tour.id, orderIds: [o1.id, o2.id, o3.id] });
  return { o1, o2, o3, tour: planned };
}

test('tournée mutualisée : regroupement des points, collecte avant livraison, refus des demandes non prêtes', async () => {
  const env = await setup();
  const { o1, o3, tour } = await plannedTour(env);
  const stops = await env.tours.stopsOf(tour.id);
  assert.equal(stops.length, 5, 'une collecte Enseigne commune, deux livraisons, une collecte et une livraison Garage');
  const pickupEns = stops.find((s) => s.type === 'PICKUP' && s.customerId === 'ENSEIGNE');
  assert.equal(pickupEns.parcelIds.length, 4);
  for (const d of stops.filter((s) => s.type === 'DELIVERY')) {
    for (const req of d.requires) assert.ok(stops.find((s) => s.id === req).sequence < d.sequence, 'collecte avant livraison');
  }
  assert.ok(tour.estimatedKm > 0);
  assert.deepEqual(tour.customerIds.sort(), ['ENSEIGNE', 'GARAGE']);
  assert.equal((await env.store.get('Order', o1.id)).status, 'PLANNED');
  const ev = await env.orders.history(o3.parcels[0].id);
  assert.deepEqual(ev.map((e) => e.type), ['CREATED', 'ASSIGNED_TO_TOUR']);

  const bad = await env.orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne', record: enseigneRecord('CMD-12', { voie: 'nulle part' }) });
  await assert.rejects(env.tours.addOrders(admin, { tourId: tour.id, orderIds: [bad.id] }), /anomalies/);
  await env.store.update('Order', bad.id, { status: 'AWAITING_PAYMENT' });
  await assert.rejects(env.tours.addOrders(admin, { tourId: tour.id, orderIds: [bad.id] }), /non payée/);
});

test('tournée dédiée et client toujours dédié', async () => {
  const env = await setup();
  await env.store.update('Customer', 'ENSEIGNE', { dedicated: true });
  const o1 = await env.orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne', record: enseigneRecord('CMD-20') });
  const o2 = await env.orders.ingest(admin, { customerId: 'GARAGE', source: 'MANUAL', record: { pickupAddress: '5 rue Lamartine, 97200 Fort-de-France', deliveryAddress: 'Route de Didier, 97200 Fort-de-France' } });
  const t = await env.tours.createTour(admin, { start: { latitude: 14.61, longitude: -61.05 } });
  await env.tours.addOrders(admin, { tourId: t.id, orderIds: [o2.id] });
  await assert.rejects(env.tours.addOrders(admin, { tourId: t.id, orderIds: [o1.id] }), /toujours en tournée dédiée/);
  const ded = await env.tours.createTour(admin, { start: { latitude: 14.61, longitude: -61.05 }, dedicatedCustomerId: 'GARAGE' });
  await assert.rejects(env.tours.addOrders(admin, { tourId: ded.id, orderIds: [o1.id] }), /dédiée à un autre client/);
});

test('exécution : scan contrôlé, preuves obligatoires, écart de position, commentaire, historique', async () => {
  const env = await setup();
  const { o1, o3, tour } = await plannedTour(env);
  const stops = await env.tours.stopsOf(tour.id);
  const pickupEns = stops.find((s) => s.type === 'PICKUP' && s.customerId === 'ENSEIGNE');
  await assert.rejects(env.tours.submitStop(courier, { stopId: pickupEns.id }), /Démarrez la tournée/);
  await env.tours.start(courier, { tourId: tour.id });

  // Colis d'un autre client et étiquette falsifiée refusés
  await assert.rejects(env.tours.scan(courier, { tourId: tour.id, stopId: pickupEns.id, code: o3.parcels[0].code }), /autre client/);
  await assert.rejects(env.tours.scan(courier, { tourId: tour.id, stopId: pickupEns.id, code: `${o1.parcels[0].code.slice(0, -3)}xxx` }), /signature/);

  // Profil Standard : scan exigé à la collecte
  const codes = [...o1.parcels, ...(await env.orders.parcelsOf(stops.find((s) => s.type === 'DELIVERY' && s.customerId === 'ENSEIGNE' && !s.orderIds.includes(o1.id)).orderIds[0]))].map((p) => p.code);
  await assert.rejects(env.tours.submitStop(courier, { stopId: pickupEns.id, scannedCodes: codes.slice(0, 1) }), /scan du colis/);
  const done = await env.tours.submitStop(courier, { stopId: pickupEns.id, scannedCodes: codes, position: { latitude: 14.6161, longitude: -61.0301 }, deviceId: 'tel-1' });
  assert.equal(done.status, 'DONE');
  assert.ok(done.distanceMeters < 50);
  await assert.rejects(env.tours.submitStop(courier, { stopId: pickupEns.id, scannedCodes: codes }), /déjà traité/);
  assert.equal((await env.store.get('Order', o1.id)).status, 'IN_PROGRESS');

  // Livraison Enseigne : photo + position exigées ; position éloignée → alerte
  const deliv1 = stops.find((s) => s.type === 'DELIVERY' && s.orderIds.includes(o1.id));
  await assert.rejects(env.tours.submitStop(courier, { stopId: deliv1.id, position: { latitude: 14.6037, longitude: -61.0731 } }), /photo/);
  const d1 = await env.tours.submitStop(courier, {
    stopId: deliv1.id, proofs: { photoKeys: ['preuves/p1.jpg'] }, position: { latitude: 14.6080, longitude: -61.0731 },
    comment: { presetId: 'gardien', text: 'Gardien très aimable' },
  });
  assert.ok(d1.distanceAlert, 'écart de plus de 200 m signalé');
  assert.equal((await env.store.get('Order', o1.id)).status, 'DONE');
  const ev = await env.orders.history(o1.parcels[0].id);
  assert.deepEqual(ev.map((e) => e.type), ['CREATED', 'ASSIGNED_TO_TOUR', 'PICKED_UP', 'DELIVERED']);
  const delivered = ev.at(-1);
  assert.equal(delivered.comment, 'Laissé au gardien', 'commentaire prédéfini visible client');
  assert.equal(delivered.internalComment, 'Gardien très aimable', 'texte libre interne');
  assert.ok(delivered.distanceMeters > 400);
  assert.equal(JSON.parse(delivered.proofs).photoKeys[0], 'preuves/p1.jpg');
  assert.equal(delivered.courierId, 'livreur-1');

  // Profil Sécurisé (client Garage) : signature avec nom exigée à la livraison
  const pickGar = stops.find((s) => s.type === 'PICKUP' && s.customerId === 'GARAGE');
  await env.tours.submitStop(courier, { stopId: pickGar.id, scannedCodes: [o3.parcels[0].code] });
  const delGar = stops.find((s) => s.type === 'DELIVERY' && s.customerId === 'GARAGE');
  await assert.rejects(env.tours.submitStop(courier, { stopId: delGar.id, scannedCodes: [o3.parcels[0].code], position: { latitude: 14.607, longitude: -61.068 }, proofs: { signatureKey: 'sig.png' } }), /signature/);
  const okGar = await env.tours.submitStop(courier, { stopId: delGar.id, scannedCodes: [o3.parcels[0].code], position: { latitude: 14.607, longitude: -61.068 }, proofs: { signatureKey: 'sig.png', signerName: 'M. Atelier' } });
  assert.equal(okGar.status, 'DONE');
});

test('échec : motif prédéfini et photo obligatoires ; clôture : incidents en mode strict', async () => {
  const env = await setup();
  const { o2, tour } = await plannedTour(env);
  const stops = await env.tours.stopsOf(tour.id);
  await env.tours.start(courier, { tourId: tour.id });
  const pickupEns = stops.find((s) => s.type === 'PICKUP' && s.customerId === 'ENSEIGNE');
  const allEns = pickupEns.parcelIds;
  const codes = [];
  for (const id of allEns) codes.push((await env.store.get('Parcel', id)).code);
  await env.tours.submitStop(courier, { stopId: pickupEns.id, scannedCodes: codes });
  const d2 = stops.find((s) => s.type === 'DELIVERY' && s.orderIds.includes(o2.id));
  await assert.rejects(env.tours.failStop(courier, { stopId: d2.id }), /motif/);
  await assert.rejects(env.tours.failStop(courier, { stopId: d2.id, comment: { presetId: 'gardien' } }), /prédéfini inconnu/);
  await assert.rejects(env.tours.failStop(courier, { stopId: d2.id, comment: { presetId: 'absent' } }), /photo/);
  const failed = await env.tours.failStop(courier, { stopId: d2.id, comment: { presetId: 'absent' }, proofs: { photoKeys: ['porte.jpg'] } });
  assert.equal(failed.status, 'FAILED');
  assert.equal((await env.store.get('Order', o2.id)).status, 'PARTIALLY_FAILED');

  await assert.rejects(env.tours.close(courier, { tourId: tour.id }), /point\(s\) restant/);
  const closed = await env.tours.close(admin, { tourId: tour.id, reason: 'Fin de service' });
  assert.equal(closed.status, 'DONE');
  // Enseigne est en mode strict : ses colis collectés mais non livrés deviennent des incidents
  assert.ok(closed.incidents.length >= 2);
  assert.ok(closed.incidents.every((i) => i.customerId === 'ENSEIGNE'), 'pas d’incident pour le client en mode souple');
  assert.ok(closed.incidents.every((i) => i.motive === 'Colis collecté mais non livré'));
});

test('étiquettes en réserve : activées au scan de collecte, abandonnées à la clôture sans incident', async () => {
  const env = await setup();
  const o = await env.orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne', record: enseigneRecord('CMD-30', { }) });
  const tour = await env.tours.createTour(admin, { start: { latitude: 14.61, longitude: -61.05 }, courierId: courier.sub, dedicatedCustomerId: 'ENSEIGNE' });
  await env.tours.addOrders(admin, { tourId: tour.id, orderIds: [o.id] });
  const reserved = await env.orders.createParcels({ id: null, customerId: 'ENSEIGNE', size: 'M', weightKg: null }, 3, { reservedForTour: tour.id });
  assert.ok(reserved.every((p) => p.labelStatus === 'RESERVED' && !p.expected));
  await env.tours.start(courier, { tourId: tour.id });
  const stops = await env.tours.stopsOf(tour.id);
  const pickup = stops.find((s) => s.type === 'PICKUP');
  await env.tours.submitStop(courier, { stopId: pickup.id, scannedCodes: [...o.parcels.map((p) => p.code), reserved[0].code] });
  const used = await env.store.get('Parcel', reserved[0].id);
  assert.equal(used.labelStatus, 'ACTIVE');
  assert.equal(used.orderId, o.id);
  const delivery = (await env.tours.stopsOf(tour.id)).find((s) => s.type === 'DELIVERY');
  assert.ok(delivery.parcelIds.includes(reserved[0].id), 'colis ajouté au point de livraison');
  await env.tours.submitStop(courier, { stopId: delivery.id, proofs: { photoKeys: ['x.jpg'] }, position: { latitude: 14.6037, longitude: -61.0731 } });
  const closed = await env.tours.close(courier, { tourId: tour.id });
  assert.equal(closed.incidents.length, 0, 'mode strict, mais les étiquettes non scannées ne sont pas des incidents');
  assert.equal((await env.store.get('Parcel', reserved[1].id)).labelStatus, 'UNUSED');
  await assert.rejects(env.tours.scan(courier, { tourId: tour.id, stopId: pickup.id, code: reserved[1].code }), /abandonnée/);
});

test('tournée démarrée gelée : ajout sous seuil de détour seulement, pas de réordonnancement', async () => {
  const env = await setup({ config: { maxAddDetourKm: 5 } });
  const { tour } = await plannedTour(env);
  await env.tours.start(courier, { tourId: tour.id });
  await assert.rejects(env.tours.optimize(admin, { tourId: tour.id }), /n’est plus réordonnée/);
  const near = await env.orders.ingest(admin, { customerId: 'GARAGE', source: 'MANUAL', record: { pickupAddress: '5 rue Lamartine, 97200 Fort-de-France', deliveryAddress: 'Rue Victor Hugo, 97200 Fort-de-France' } });
  const before = await env.tours.stopsOf(tour.id);
  const t2 = await env.tours.addOrders(admin, { tourId: tour.id, orderIds: [near.id] });
  const after = await env.tours.stopsOf(tour.id);
  assert.deepEqual(after.slice(0, before.length).map((s) => s.id), before.map((s) => s.id), 'points existants inchangés');
  assert.equal(after.length, before.length + 2);
  assert.match(t2.notices.at(-1).message, /ajouté/);
  const far = await env.orders.ingest(admin, { customerId: 'GARAGE', source: 'MANUAL', record: { pickupAddress: 'Zone de la Jambette, 97232 Le Lamentin', deliveryAddress: 'Route de Didier, 97200 Fort-de-France' } });
  await assert.rejects(env.tours.addOrders(admin, { tourId: tour.id, orderIds: [far.id] }), /détour/);
  await assert.rejects(env.tours.removeOrder(admin, { tourId: tour.id, orderId: near.id }), /motif/);
});

test('heure limite impossible : alerte au dispatcher, démarrage bloqué', async () => {
  const env = await setup();
  const o = await env.orders.ingest(admin, { customerId: 'GARAGE', source: 'MANUAL', record: {
    pickupAddress: 'Zone de la Jambette, 97232 Le Lamentin', deliveryAddress: 'Route de Didier, 97200 Fort-de-France', deadlineAt: '2026-11-04T03:05:00.000Z',
  } });
  const tour = await env.tours.createTour(admin, { date: '2026-11-04', slot: 'NIGHT', start: { latitude: 14.65, longitude: -61.00 }, courierId: courier.sub });
  const planned = await env.tours.addOrders(admin, { tourId: tour.id, orderIds: [o.id] });
  assert.equal(planned.alerts[0].code, 'DEADLINE_MISSED');
  await assert.rejects(env.tours.start(courier, { tourId: tour.id }), /Heure limite/);
});

test('vue client cloisonnée : uniquement ses points, position du livreur tant qu’il lui reste un point', async () => {
  const env = await setup();
  const { o3, tour } = await plannedTour(env);
  await env.tours.start(courier, { tourId: tour.id });
  await env.store.put('CourierPosition', { id: courier.sub, latitude: 14.61, longitude: -61.05, at: '2026-11-04T05:00:00Z' });
  const view = await env.tours.clientView(garage, { tourId: tour.id });
  assert.equal(view.stops.length, 2);
  assert.ok(view.stops.every((s) => o3.parcels.some((p) => s.parcelIds.includes(p.id))), 'aucun point ni colis d’un autre client');
  assert.ok(view.courier, 'position visible tant qu’un point du client reste à faire');
  assert.equal(view.route, null, 'aucun trajet affiché par défaut');
  const stops = await env.tours.stopsOf(tour.id);
  await env.tours.submitStop(courier, { stopId: stops.find((s) => s.type === 'PICKUP' && s.customerId === 'GARAGE').id, scannedCodes: [o3.parcels[0].code] });
  await env.tours.submitStop(courier, { stopId: stops.find((s) => s.type === 'DELIVERY' && s.customerId === 'GARAGE').id, scannedCodes: [o3.parcels[0].code], position: { latitude: 14.607, longitude: -61.068 }, proofs: { signatureKey: 's', signerName: 'X' } });
  assert.equal((await env.tours.clientView(garage, { tourId: tour.id })).courier, null, 'plus de position une fois ses points faits');
  await assert.rejects(env.tours.clientView({ sub: 'x', groups: ['client'], clientName: 'AUTRE' }, { tourId: tour.id }), /introuvable/);
});

test('position du livreur : seulement pendant une tournée en cours (RGPD), trace conservée', async () => {
  const env = await setup();
  await assert.rejects(env.tours.recordPosition(courier, { latitude: 14.6, longitude: -61.0 }), /Aucune tournée en cours/);
  const { tour } = await plannedTour(env);
  await env.tours.start(courier, { tourId: tour.id });
  const r = await env.tours.recordPosition(courier, { latitude: 14.6, longitude: -61.0 });
  assert.equal(r.tourId, tour.id);
  assert.equal((await env.store.get('CourierPosition', courier.sub)).latitude, 14.6);
  assert.equal((await env.store.query('TracePoint', 'byTour', 'tourId', tour.id)).length, 1);
});

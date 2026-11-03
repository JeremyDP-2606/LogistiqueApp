const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createService, MAX_CODE_ATTEMPTS } = require('../src/lib/service');
const { createMemoryStore } = require('./memoryStore');
const geohash = require('../src/lib/geohash');
const { quote } = require('../src/lib/pricing');
const { form } = require('../src/lib/stripe');
const { handle } = require('../src/index');

// Fort-de-France : retrait rue Victor Hugo, livraison quartier Didier
const PICKUP = { address: '12 rue Victor Hugo, Fort-de-France', latitude: 14.6037, longitude: -61.0731, contactName: 'Boutique', phone: '0596000000' };
const DROPOFF = { address: 'Route de Didier, Fort-de-France', latitude: 14.6280, longitude: -61.0800, contactName: 'Alice' };

const client = { sub: 'client-1', groups: [], name: 'Alice Client', email: 'alice@example.com' };
const client2 = { sub: 'client-2', groups: [] };
const courierA = { sub: 'livreur-a', groups: ['livreur'], name: 'Léa' };
const courierB = { sub: 'livreur-b', groups: ['livreur'], name: 'Karim' };
const admin = { sub: 'admin-1', groups: ['admin'] };
const pro = { sub: 'pro-1', groups: ['client'], clientName: 'France-Antilles', name: 'Service courrier' };

function fakeStripe() {
  const intents = new Map();
  let n = 0;
  return {
    intents,
    async createAuthorization({ amount, courseId }) {
      const pi = { id: `pi_${++n}`, client_secret: `pi_${n}_secret`, amount: Math.round(amount * 100), status: 'requires_payment_method', courseId };
      intents.set(pi.id, pi);
      return pi;
    },
    authorize(id) { intents.get(id).status = 'requires_capture'; },
    async retrieve(id) { return intents.get(id); },
    async capture(id) { intents.get(id).status = 'succeeded'; return intents.get(id); },
    async cancel(id) { intents.get(id).status = 'canceled'; return intents.get(id); },
  };
}
const fakeGoogle = { async route() { return { distanceKm: 3.2, durationMin: 9, source: 'google' }; } };
const quietLog = { warn() {}, error() {}, log() {} };

function setup() {
  const store = createMemoryStore();
  const stripe = fakeStripe();
  const svc = createService({ store, stripe, google: fakeGoogle, log: quietLog });
  return { store, stripe, svc };
}

async function onlineCourier(svc, who, vehicle = 'BIKE', pos = { latitude: 14.605, longitude: -61.07 }) {
  await svc.setCourierAvailability(who, { online: true, vehicle });
  await svc.updateCourierPosition(who, pos);
}

async function paidCourse(svc, stripe, who = client, extra = {}) {
  const r = await svc.createCourse(who, { input: { pickup: PICKUP, dropoff: DROPOFF, packageSize: 'S', urgency: 'STANDARD', vehicle: 'BIKE', ...extra } });
  if (r.course.paymentIntentId) stripe.authorize(r.course.paymentIntentId);
  await svc.confirmCoursePayment(who, { courseId: r.course.id });
  return r;
}

test('tarification : options triées, contraintes de taille et majoration express', () => {
  const route = { distanceKm: 3.2, durationMin: 9 };
  const s = quote({ route, packageSize: 'S', urgency: 'STANDARD' });
  assert.deepEqual(s.options.map((o) => o.vehicle), ['BIKE', 'MOTORBIKE', 'CAR', 'VAN']);
  assert.deepEqual(quote({ route, packageSize: 'L', urgency: 'STANDARD' }).options.map((o) => o.vehicle), ['CAR', 'VAN']);
  const e = quote({ route, packageSize: 'S', urgency: 'EXPRESS' });
  assert.ok(e.options[0].priceTtc > s.options[0].priceTtc);
  const o = s.options[0];
  assert.equal(o.priceTtc, Math.round((o.priceHt + o.priceTva) * 100) / 100);
  assert.equal(quote({ route: { distanceKm: 20 }, packageSize: 'S', urgency: 'STANDARD' }).options[0].vehicle, 'CAR');
});

test('geohash : encodage connu et voisinage de 9 cellules', () => {
  assert.equal(geohash.encode(48.8584, 2.2945, 7), 'u09tunq'); // tour Eiffel
  const cells = geohash.neighborhood('ddgwm');
  assert.equal(cells.length, 9);
  assert.ok(cells.includes('ddgwm'));
});

test('stripe : encodage des formulaires imbriqués', () => {
  assert.equal(form({ amount: 1205, metadata: { courseId: 'a b' } }), 'amount=1205&metadata%5BcourseId%5D=a%20b');
});

test('parcours complet : commande, paiement, acceptation, étapes, code, encaissement, note', async () => {
  const { svc, stripe, store } = setup();
  await onlineCourier(svc, courierA);

  const q = await svc.quoteCourse(client, { pickup: PICKUP, dropoff: DROPOFF, packageSize: 'S', urgency: 'STANDARD' });
  assert.equal(q.distanceKm, 3.2);
  assert.equal(q.tarif, undefined, 'le devis ne renvoie pas la grille interne');

  const created = await svc.createCourse(client, { input: { pickup: PICKUP, dropoff: DROPOFF, packageSize: 'S', urgency: 'STANDARD', vehicle: 'BIKE' } });
  const c = created.course;
  assert.equal(c.status, 'AWAITING_PAYMENT');
  assert.equal(c.paymentMode, 'CARD');
  assert.equal(created.paymentClientSecret, 'pi_1_secret');
  assert.match(created.deliveryCode, /^\d{4}$/);
  assert.equal(c.deliveryCode, undefined, 'le code ne doit pas être dans la course');
  assert.equal(stripe.intents.get(c.paymentIntentId).amount, Math.round(c.priceTtc * 100));

  // Pas encore payée : invisible pour les livreurs
  assert.equal((await svc.availableCourses(courierA)).length, 0);
  await assert.rejects(svc.confirmCoursePayment(client, { courseId: c.id }), /paiement/);
  stripe.authorize(c.paymentIntentId);
  await assert.rejects(svc.confirmCoursePayment(client2, { courseId: c.id }), /introuvable/);
  const pending = await svc.confirmCoursePayment(client, { courseId: c.id });
  assert.equal(pending.status, 'PENDING');
  assert.equal((await svc.confirmCoursePayment(client, { courseId: c.id })).status, 'PENDING', 'idempotent');

  const avail = await svc.availableCourses(courierA);
  assert.equal(avail.length, 1);
  assert.ok(avail[0].distanceToPickupKm < 1);

  const assigned = await svc.acceptCourse(courierA, { courseId: c.id });
  assert.equal(assigned.status, 'ASSIGNED');
  assert.equal(assigned.courierId, 'livreur-a');
  assert.equal((await store.get('CourierProfile', 'livreur-a')).activeCourseId, c.id);

  const pos = await svc.updateCourierPosition(courierA, { latitude: 14.604, longitude: -61.072 });
  assert.equal(pos.courseId, c.id, 'la position est rattachée à la course pour le suivi en direct');

  await assert.rejects(svc.updateCourseStep(courierA, { courseId: c.id, status: 'COMPLETED', code: created.deliveryCode }), /Étape impossible/);
  for (const s of ['PICKING_UP', 'PICKED_UP', 'DELIVERING']) {
    assert.equal((await svc.updateCourseStep(courierA, { courseId: c.id, status: s })).status, s);
  }
  const wrong = created.deliveryCode === '0000' ? '1111' : '0000';
  await assert.rejects(svc.updateCourseStep(courierA, { courseId: c.id, status: 'COMPLETED', code: wrong }), /incorrect/);
  const done = await svc.updateCourseStep(courierA, { courseId: c.id, status: 'COMPLETED', code: created.deliveryCode });
  assert.equal(done.status, 'COMPLETED');
  assert.equal(done.paymentStatus, 'captured');
  assert.equal(stripe.intents.get(c.paymentIntentId).status, 'succeeded');
  assert.equal((await store.get('CourierProfile', 'livreur-a')).activeCourseId, null, 'livreur libéré');

  const events = await store.query('CourseEvent', 'byCourse', 'courseId', c.id);
  assert.deepEqual(events.map((e) => e.status).sort(), ['ASSIGNED', 'AWAITING_PAYMENT', 'COMPLETED', 'DELIVERING', 'PENDING', 'PICKED_UP', 'PICKING_UP'].sort());

  const rated = await svc.rateCourse(client, { courseId: c.id, stars: 4, comment: 'Rapide' });
  assert.equal(rated.ratingStars, 4);
  await assert.rejects(svc.rateCourse(client, { courseId: c.id, stars: 5 }), /déjà/);
  assert.equal((await store.get('CourierProfile', 'livreur-a')).rating, 4);

  const earnings = await svc.courierEarnings(courierA);
  assert.equal(earnings.total.count, 1);
  assert.equal(earnings.total.amount, c.courierEarning);
});

test('deux livreurs acceptent la même course : un seul l’obtient', async () => {
  const { svc, stripe } = setup();
  await onlineCourier(svc, courierA);
  await onlineCourier(svc, courierB);
  const { course } = await paidCourse(svc, stripe);
  const results = await Promise.allSettled([
    svc.acceptCourse(courierA, { courseId: course.id }),
    svc.acceptCourse(courierB, { courseId: course.id }),
  ]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.match(results.find((r) => r.status === 'rejected').reason.message, /plus disponible|autre livreur/);
});

test('un livreur occupé ne peut pas prendre une deuxième course', async () => {
  const { svc, stripe } = setup();
  await onlineCourier(svc, courierA);
  const a = await paidCourse(svc, stripe);
  const b = await paidCourse(svc, stripe);
  await svc.acceptCourse(courierA, { courseId: a.course.id });
  await assert.rejects(svc.acceptCourse(courierA, { courseId: b.course.id }), /déjà une course/);
});

test('code de remise : bloqué après trop d’essais', async () => {
  const { svc, stripe } = setup();
  await onlineCourier(svc, courierA);
  const { course, deliveryCode } = await paidCourse(svc, stripe);
  await svc.acceptCourse(courierA, { courseId: course.id });
  for (const s of ['PICKING_UP', 'PICKED_UP', 'DELIVERING']) await svc.updateCourseStep(courierA, { courseId: course.id, status: s });
  const wrong = deliveryCode === '0000' ? '1111' : '0000';
  for (let i = 0; i < MAX_CODE_ATTEMPTS; i++) {
    await assert.rejects(svc.updateCourseStep(courierA, { courseId: course.id, status: 'COMPLETED', code: wrong }), /incorrect/);
  }
  await assert.rejects(svc.updateCourseStep(courierA, { courseId: course.id, status: 'COMPLETED', code: deliveryCode }), /support/);
});

test('annulation par le client : autorisation de paiement libérée, livreur libéré', async () => {
  const { svc, stripe, store } = setup();
  await onlineCourier(svc, courierA);
  const { course } = await paidCourse(svc, stripe);
  await svc.acceptCourse(courierA, { courseId: course.id });
  await assert.rejects(svc.cancelCourse(client2, { courseId: course.id }), /introuvable/);
  const cancelled = await svc.cancelCourse(client, { courseId: course.id });
  assert.equal(cancelled.status, 'CANCELLED');
  assert.equal(cancelled.paymentStatus, 'cancelled');
  assert.equal(stripe.intents.get(course.paymentIntentId).status, 'canceled');
  assert.equal((await store.get('CourierProfile', 'livreur-a')).activeCourseId, null);
  await assert.rejects(svc.cancelCourse(client, { courseId: course.id }), /ne peut plus/);
});

test('le client ne peut plus annuler une fois le colis récupéré, Wabap si', async () => {
  const { svc, stripe } = setup();
  await onlineCourier(svc, courierA);
  const { course } = await paidCourse(svc, stripe);
  await svc.acceptCourse(courierA, { courseId: course.id });
  await svc.updateCourseStep(courierA, { courseId: course.id, status: 'PICKING_UP' });
  await svc.updateCourseStep(courierA, { courseId: course.id, status: 'PICKED_UP' });
  await assert.rejects(svc.cancelCourse(client, { courseId: course.id }), /ne peut plus/);
  assert.equal((await svc.cancelCourse(admin, { courseId: course.id, reason: 'Colis refusé' })).status, 'CANCELLED');
});

test('client professionnel avec facturation : pas de paiement par carte', async () => {
  const { svc, stripe, store } = setup();
  await store.put('Tarif', { id: 'France-Antilles', invoice: true, vehicles: '[]', expressMultiplier: 1.2, vatRate: 0.085, courierShare: 0.8 });
  const r = await svc.createCourse(pro, { input: { pickup: PICKUP, dropoff: DROPOFF, packageSize: 'S', urgency: 'STANDARD' } });
  assert.equal(r.course.paymentMode, 'INVOICE');
  assert.equal(r.paymentClientSecret, null);
  assert.equal(r.course.owner, 'France-Antilles');
  assert.equal(stripe.intents.size, 0);
  assert.equal(r.course.priceTva, Math.round(r.course.priceHt * 0.085 * 100) / 100, 'TVA Martinique de la grille du client');
  assert.equal((await svc.confirmCoursePayment(pro, { courseId: r.course.id })).status, 'PENDING');
});

test('droits : opérations livreur réservées au groupe livreur, véhicule vérifié', async () => {
  const { svc, stripe } = setup();
  await assert.rejects(svc.setCourierAvailability(client, { online: true, vehicle: 'BIKE' }), /livreurs/);
  await assert.rejects(svc.availableCourses(client), /livreurs/);
  await onlineCourier(svc, courierB, 'CAR');
  const { course } = await paidCourse(svc, stripe);
  assert.equal((await svc.availableCourses(courierB)).length, 0, 'course vélo invisible pour une voiture');
  await assert.rejects(svc.acceptCourse(courierB, { courseId: course.id }), /véhicule/);
});

test('validation des entrées', async () => {
  const { svc } = setup();
  await assert.rejects(svc.quoteCourse(client, { pickup: { address: '' }, dropoff: DROPOFF, packageSize: 'S', urgency: 'STANDARD' }), /retrait/);
  await assert.rejects(svc.quoteCourse(client, { pickup: PICKUP, dropoff: { ...DROPOFF, latitude: 200 }, packageSize: 'S', urgency: 'STANDARD' }), /livraison/);
  await assert.rejects(svc.quoteCourse(client, { pickup: PICKUP, dropoff: DROPOFF, packageSize: 'XXL', urgency: 'STANDARD' }), /Taille/);
});

test('résolveur AppSync : identité extraite, erreurs internes masquées', async () => {
  const { svc } = setup();
  const event = (fieldName, args, groups = []) => ({ fieldName, arguments: args, identity: { sub: 'u1', groups, claims: { email: 'u1@example.com' } } });
  const q = await handle(event('quoteCourse', { pickup: PICKUP, dropoff: DROPOFF, packageSize: 'S', urgency: 'STANDARD' }), svc);
  assert.equal(q.options[0].vehicle, 'BIKE');
  await assert.rejects(handle(event('availableCourses', {}), svc), /livreurs/);
  await assert.rejects(handle({ fieldName: 'quoteCourse', arguments: {} }, svc), /Authentification/);
  const broken = { quoteCourse: async () => { throw new Error('secret interne'); } };
  const orig = console.error; console.error = () => {};
  await assert.rejects(handle(event('quoteCourse', {}), broken), /Erreur serveur/);
  console.error = orig;
});

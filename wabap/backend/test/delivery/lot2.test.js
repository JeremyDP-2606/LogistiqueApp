// Lot 2 : courses ponctuelles (prix, paiement avant prise en charge, remboursements, suivi par étapes).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryStore } = require('./memoryStore');
const { createOrders } = require('../../src/delivery/lib/orders');
const { createTours } = require('../../src/delivery/lib/tours');
const { createCourses } = require('../../src/delivery/lib/courses');
const { priceCourse, gridAt, DEFAULT_GRID } = require('../../src/delivery/lib/pricing');

const particulier = { sub: 'part-1', groups: [], name: 'Marie-Line', email: 'ml@exemple.fr' };
const autre = { sub: 'part-2', groups: [] };
const admin = { sub: 'admin', groups: ['admin'] };
const courier = { sub: 'livreur-1', groups: ['livreur'] };

const A = { address: { formatted: 'Rue Victor Hugo, 97200 Fort-de-France', street: 'Rue Victor Hugo', latitude: 14.6037, longitude: -61.0731 }, name: 'Marie-Line', phone: '0696112233' };
const B = { address: { formatted: 'Route de Didier, 97200 Fort-de-France', street: 'Route de Didier', latitude: 14.6280, longitude: -61.0800 }, name: 'JEAN BAPTISTE', phone: '0696445566' };

function fakeStripe() {
  const intents = new Map();
  const refunds = [];
  return {
    intents, refunds,
    async createPayment({ amount, orderId }) {
      const pi = { id: `pi_${orderId.slice(0, 6)}`, client_secret: 'secret', amount: Math.round(amount * 100), status: 'requires_payment_method' };
      intents.set(pi.id, pi);
      return pi;
    },
    pay(id) { intents.get(id).status = 'succeeded'; },
    async retrieve(id) { return intents.get(id); },
    async refund(id, { amount, reason }) { refunds.push({ id, amount, reason }); return { id: 're_1' }; },
  };
}

async function setup(now = '2026-11-04T14:00:00Z') {
  const store = createMemoryStore();
  const stripe = fakeStripe();
  const ctx = { store, stripe, labelSecret: 's', geocoder: null, router: { km: async () => 4 }, now: () => new Date(now) };
  const orders = createOrders(ctx);
  const tours = createTours(ctx, orders);
  const courses = createCourses(ctx, orders, tours);
  ctx.hooks = { onOrderStatus: courses.onOrderStatus };
  await store.put('ProofProfile', { id: 'course', pickup: { scan: true }, delivery: { photo: true, otp: true } });
  await store.put('PriceGrid', { id: 'g1', kind: 'COURSE', effectiveFrom: '2026-01-01T00:00:00.000Z', proofProfileId: 'course' });
  await store.put('PromoCode', { id: 'BIENVENUE', percent: 10, active: true });
  for (const [id, kind, label, clientVisible] of [['absent', 'FAILURE', 'Destinataire absent', true]]) {
    await store.put('CommentPreset', { id, kind, label, clientVisible, active: 'yes' });
  }
  return { store, stripe, orders, tours, courses };
}

test('formule de la spec : (prise en charge + km × prix/km) × coef délai, avec minimum', () => {
  // M, 10 km, 1 jour : (7 + 10 × 1,00) × 1,5 = 25,50 €
  assert.equal(priceCourse(DEFAULT_GRID, 10, { size: 'M', maxDays: 1 }).total, 25.5);
  // S, 3 km, 3 jours : (5 + 2,40) × 1 = 7,40 € → minimum 10 €
  const small = priceCourse(DEFAULT_GRID, 3, { size: 'S', maxDays: 3 });
  assert.equal(small.total, 10);
  assert.ok(small.lines.some((l) => /Minimum/.test(l.label)));
  // Suppléments et code promo
  const opt = priceCourse(DEFAULT_GRID, 10, { size: 'M', maxDays: 2, options: { deadline: true, weekend: true } }, { code: 'X', percent: 10 });
  // (7 + 10) × 1,2 = 20,40 ; + 5 ; + 15 % de 20,40 = 3,06 → 28,46 ; − 10 % = 25,61
  assert.equal(opt.total, 25.61);
  assert.equal(Math.round(opt.lines.reduce((s, l) => s + l.amount, 0) * 100) / 100, opt.total, 'le détail additionne au total');
  assert.throws(() => priceCourse(DEFAULT_GRID, 5, { size: 'S', weightKg: 8, maxDays: 1 }), /choisissez M/);
  assert.throws(() => priceCourse(DEFAULT_GRID, 5, { size: 'XL', weightKg: 80, maxDays: 1 }), /hors gabarit/);
  assert.throws(() => priceCourse(DEFAULT_GRID, 5, { size: 'S', maxDays: 5 }), /Délai/);
});

test('grille historisée : la grille en vigueur à la date', () => {
  const grids = [
    { id: 'v1', effectiveFrom: '2026-01-01T00:00:00.000Z', minimum: 10 },
    { id: 'v2', effectiveFrom: '2026-12-01T00:00:00.000Z', minimum: 12 },
    { id: 'brouillon', effectiveFrom: '2026-02-01T00:00:00.000Z', minimum: 99, status: 'DRAFT' },
  ];
  assert.equal(gridAt(grids, '2026-11-04T00:00:00.000Z').id, 'v1');
  assert.equal(gridAt(grids, '2026-12-02T00:00:00.000Z').id, 'v2');
});

test('course : paiement avant prise en charge, prix figé, code de confirmation pour le donneur d’ordre', async () => {
  const { courses, stripe, tours, store } = await setup();
  const q = await courses.quote(particulier, { pickup: A, delivery: B, size: 'M', maxDays: 2, promoCode: 'bienvenue' });
  assert.equal(q.price.total, Math.round((7 + 4) * 1.2 * 0.9 * 100) / 100);
  assert.equal(q.deadlineAt, '2026-11-07T03:59:00.000Z', 'fin de journée locale à J+2 (UTC−4)');

  const r = await courses.create(particulier, { pickup: A, delivery: B, size: 'M', maxDays: 2 });
  assert.equal(r.order.status, 'AWAITING_PAYMENT');
  assert.equal(r.order.customerId, 'IND-part-1');
  assert.equal(r.order.delivery.contact.name, 'Jean Baptiste');
  assert.equal(r.order.deadlineAt, q.deadlineAt);
  assert.match(r.otpCode, /^\d{4}$/);
  assert.equal(stripe.intents.get(r.order.paymentIntentId).amount, Math.round(r.order.priceTotal * 100));

  // Non payée : n'entre jamais dans une tournée
  const tour = await tours.createTour(admin, { start: { latitude: 14.61, longitude: -61.05 }, courierId: courier.sub });
  await assert.rejects(tours.addOrders(admin, { tourId: tour.id, orderIds: [r.order.id] }), /non payée/);
  await assert.rejects(courses.confirmPayment(particulier, { orderId: r.order.id }), /n’a pas abouti/);
  stripe.pay(r.order.paymentIntentId);
  await assert.rejects(courses.confirmPayment(autre, { orderId: r.order.id }), /introuvable/);
  const paid = await courses.confirmPayment(particulier, { orderId: r.order.id });
  assert.equal(paid.status, 'CREATED');
  await tours.addOrders(admin, { tourId: tour.id, orderIds: [r.order.id] });

  // Une modification de grille ne change pas le prix d'une course déjà payée
  await store.put('PriceGrid', { id: 'g2', kind: 'COURSE', effectiveFrom: '2026-11-01T00:00:00.000Z', minimum: 50 });
  assert.equal((await store.get('Order', r.order.id)).priceTotal, r.order.priceTotal);
  assert.equal((await courses.quote(particulier, { pickup: A, delivery: B, size: 'S', maxDays: 3 })).price.total, 50);
});

test('annulation avant collecte : retrait de la tournée et remboursement total', async () => {
  const { courses, stripe, tours, store } = await setup();
  const r = await courses.create(particulier, { pickup: A, delivery: B, size: 'S', maxDays: 1 });
  stripe.pay(r.order.paymentIntentId);
  await courses.confirmPayment(particulier, { orderId: r.order.id });
  const tour = await tours.createTour(admin, { start: { latitude: 14.61, longitude: -61.05 }, courierId: courier.sub });
  await tours.addOrders(admin, { tourId: tour.id, orderIds: [r.order.id] });
  const c = await courses.cancel(particulier, { orderId: r.order.id });
  assert.equal(c.status, 'CANCELLED');
  assert.equal(c.paymentStatus, 'refunded');
  assert.equal(stripe.refunds.length, 1);
  assert.equal((await store.get('Tour', tour.id)).orderIds.length, 0, 'retirée de la tournée');
  await assert.rejects(courses.cancel(particulier, { orderId: r.order.id }), /ne peut plus/);
});

test('échec de livraison : remboursement automatique ; suivi par étapes sans commentaire interne', async () => {
  const { courses, stripe, tours, store, orders } = await setup();
  const r = await courses.create(particulier, { pickup: A, delivery: B, size: 'S', maxDays: 1 });
  stripe.pay(r.order.paymentIntentId);
  await courses.confirmPayment(particulier, { orderId: r.order.id });
  const tour = await tours.createTour(admin, { start: { latitude: 14.61, longitude: -61.05 }, courierId: courier.sub });
  await tours.addOrders(admin, { tourId: tour.id, orderIds: [r.order.id] });
  await tours.start(courier, { tourId: tour.id });
  const [pickup, delivery] = (await tours.stopsOf(tour.id));
  const parcel = (await orders.parcelsOf(r.order.id))[0];
  await tours.submitStop(courier, { stopId: pickup.id, scannedCodes: [parcel.code] });
  await assert.rejects(courses.cancel(particulier, { orderId: r.order.id }), /déjà pris en charge/);
  // Livraison : photo + code de confirmation exigés par le profil « course »
  await assert.rejects(tours.submitStop(courier, { stopId: delivery.id, proofs: { photoKeys: ['p.jpg'], otpCode: '0000' === r.otpCode ? '1111' : '0000' } }), /code de confirmation/);
  await tours.failStop(courier, { stopId: delivery.id, comment: { presetId: 'absent', text: 'Chien agressif' }, proofs: { photoKeys: ['porte.jpg'] } });
  const order = await store.get('Order', r.order.id);
  assert.equal(order.status, 'PARTIALLY_FAILED');
  assert.equal(order.paymentStatus, 'refunded');
  assert.match(stripe.refunds[0].reason, /Destinataire absent/);

  const view = await courses.clientView(particulier, { orderId: r.order.id });
  assert.deepEqual(view.steps.map((s) => s.key), ['PAID', 'PLANNED', 'PICKED_UP', 'OUT_FOR_DELIVERY', 'FAILED']);
  assert.equal(view.currentStep, 'FAILED');
  assert.equal(view.steps.at(-1).detail, 'Destinataire absent');
  assert.equal(view.proofs.at(-1).photoKeys[0], 'porte.jpg');
  assert.ok(!JSON.stringify(view).includes('Chien agressif'), 'le texte libre du livreur reste interne');
  assert.equal(view.order.rawInput, undefined);
  await assert.rejects(courses.clientView(autre, { orderId: r.order.id }), /introuvable/);
});

test('geste commercial : remboursement partiel motivé, réservé à Wabap, plafonné', async () => {
  const { courses, stripe } = await setup();
  const r = await courses.create(particulier, { pickup: A, delivery: B, size: 'L', maxDays: 1 });
  stripe.pay(r.order.paymentIntentId);
  await courses.confirmPayment(particulier, { orderId: r.order.id });
  await assert.rejects(courses.gesture(particulier, { orderId: r.order.id, amount: 2, reason: 'x' }), /équipes Wabap/);
  await assert.rejects(courses.gesture(admin, { orderId: r.order.id, amount: 2 }), /motif/);
  const g = await courses.gesture(admin, { orderId: r.order.id, amount: 5, reason: 'Retard' });
  assert.equal(g.paymentStatus, 'partially_refunded');
  assert.equal(g.refundedAmount, 5);
  await assert.rejects(courses.gesture(admin, { orderId: r.order.id, amount: 1000, reason: 'x' }), /dépasse/);
});

test('client pro en compte : pas de paiement, demande directement prête à planifier', async () => {
  const { courses, store, stripe } = await setup();
  await store.put('Customer', { id: 'GARAGE', name: 'Garage', billingMode: 'ACCOUNT' });
  const r = await courses.create({ sub: 'g', groups: ['client'], clientName: 'GARAGE' }, { pickup: A, delivery: B, size: 'S', maxDays: 3 });
  assert.equal(r.order.status, 'CREATED');
  assert.equal(r.paymentClientSecret, null);
  assert.equal(stripe.intents.size, 0);
});

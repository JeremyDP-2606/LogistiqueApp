// Lot 4 : rémunération des livreurs.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createMemoryStore } = require('./memoryStore');
const { createOrders } = require('../src/lib/orders');
const { createTours } = require('../src/lib/tours');
const { createEarnings, computeEarning, gridAt, slotAt, DEFAULT_RATE_GRID } = require('../src/lib/earnings');

const GRID = {
  id: 'g', effectiveFrom: '2026-01-01T00:00:00.000Z',
  rates: { 'grand-compte': { DAY: 0.5, NIGHT: 0.7 }, pme: { DAY: 0.6, NIGHT: 0.9 }, default: { DAY: 0.6, NIGHT: 0.8 } },
  nightStart: '21:00', nightEnd: '06:00', perStop: 0.5, perParcel: 0, minimumPerTour: 0, weekendPercent: 10,
  heavyParcelKg: 25, heavyParcelBonus: 2, splitRule: 'POINTS',
};
// Heure locale Martinique = UTC − 4
const stop = (legKm, etaUtc, type, parcels = [{ delivered: true }], status = 'DONE') => ({ legKm, eta: etaUtc, customerTypeId: type, parcels, status });

test('créneau jour / nuit selon l’heure locale, plage de nuit à cheval sur minuit', () => {
  assert.equal(slotAt('2026-11-04T09:30:00Z', GRID, -240), 'NIGHT'); // 05:30 locale
  assert.equal(slotAt('2026-11-04T10:00:00Z', GRID, -240), 'DAY'); // 06:00 locale
  assert.equal(slotAt('2026-11-05T01:30:00Z', GRID, -240), 'NIGHT'); // 21:30 locale
});

test('tournée qui chevauche nuit et jour : chaque tronçon au tarif de son heure', () => {
  const tour = { startTime: '2026-11-04T09:00:00Z' }; // mercredi
  const r = computeEarning(tour, [
    stop(10, '2026-11-04T09:20:00Z', 'grand-compte'), // nuit : 10 × 0,70
    stop(20, '2026-11-04T10:30:00Z', 'grand-compte'), // jour : 20 × 0,50
  ], GRID);
  assert.equal(r.km, 30);
  assert.equal(r.amount, 7 + 10 + 2 * 0.5, 'km + forfait par point');
  assert.deepEqual(r.lines.filter((l) => l.kind === 'KM').map((l) => [l.slot, l.amount]), [['DAY', 10], ['NIGHT', 7]]);
});

test('tournée mutualisée : répartition des km au prorata des points, des colis ou des km attribuables', () => {
  const tour = { startTime: '2026-11-04T12:00:00Z' };
  const stops = [
    stop(30, '2026-11-04T12:30:00Z', 'grand-compte', [{ delivered: true }, { delivered: true }, { delivered: true }]),
    stop(10, '2026-11-04T13:00:00Z', 'pme', [{ delivered: true }]),
  ];
  const km = (rule) => computeEarning(tour, stops, { ...GRID, perStop: 0, splitRule: rule }).lines.map((l) => [l.customerTypeId, l.km]);
  assert.deepEqual(km('POINTS'), [['grand-compte', 20], ['pme', 20]]);
  assert.deepEqual(km('PARCELS'), [['grand-compte', 30], ['pme', 10]]);
  assert.deepEqual(km('KM'), [['grand-compte', 30], ['pme', 10]]);
  // Montant au tarif de chaque type : POINTS → 20 × 0,5 + 20 × 0,6 = 22
  assert.equal(computeEarning(tour, stops, { ...GRID, perStop: 0, splitRule: 'POINTS' }).amount, 22);
});

test('options : colis lourds, majoration week-end, minimum par tournée', () => {
  const samedi = { startTime: '2026-11-07T12:00:00Z' };
  const r = computeEarning(samedi, [stop(10, '2026-11-07T12:30:00Z', 'pme', [{ delivered: true, weightKg: 30 }, { delivered: true, weightKg: 2 }])], GRID);
  // 10 × 0,6 = 6 ; + 1 point × 0,5 ; + 1 colis lourd × 2 ; + 10 % de 6 = 0,6
  assert.equal(r.amount, 9.1);
  const mini = computeEarning({ startTime: '2026-11-04T12:00:00Z' }, [stop(1, '2026-11-04T12:10:00Z', 'pme')], { ...GRID, minimumPerTour: 25 });
  assert.equal(mini.amount, 25);
  assert.ok(mini.lines.some((l) => l.kind === 'MINIMUM'));
});

test('grille historisée : une tournée est payée selon la grille en vigueur à sa date', () => {
  const grids = [{ ...GRID, id: 'v1' }, { ...GRID, id: 'v2', effectiveFrom: '2026-12-01T00:00:00.000Z' }];
  assert.equal(gridAt(grids, '2026-11-30T23:00:00Z').id, 'v1');
  assert.equal(gridAt(grids, '2026-12-01T08:00:00Z').id, 'v2');
  assert.equal(gridAt([], '2026-11-01T00:00:00Z').id, DEFAULT_RATE_GRID.id);
});

test('de la clôture au paiement : gain à valider, ajustement motivé, relevé mensuel, export CSV', async () => {
  const store = createMemoryStore();
  const ctx = { store, labelSecret: 's', now: () => new Date('2026-11-04T12:00:00Z') };
  const orders = createOrders(ctx);
  const tours = createTours(ctx, orders);
  const earnings = createEarnings(ctx);
  ctx.hooks = { onTourClosed: earnings.onTourClosed };
  await store.put('RateGrid', { ...GRID, kind: 'COURIER', rates: JSON.stringify(GRID.rates) });
  await store.put('Customer', { id: 'ENSEIGNE', name: 'Enseigne', customerTypeId: 'grand-compte' });
  await store.put('CourierProfile', { id: 'livreur-1', name: 'Steeve' });
  const admin = { sub: 'admin', groups: ['admin'] };
  const courier = { sub: 'livreur-1', groups: ['livreur'] };
  const pt = (lat, lng) => ({ formatted: 'x', street: 'x', latitude: lat, longitude: lng });
  const o = await orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'MANUAL', record: { pickupAddress: pt(14.61, -61.03), deliveryAddress: pt(14.63, -61.08), deliveryName: 'X' } });
  const tour = await tours.createTour(admin, { date: '2026-11-04', startTime: '2026-11-04T12:00:00.000Z', start: { latitude: 14.6, longitude: -61.0 }, courierId: courier.sub });
  await tours.addOrders(admin, { tourId: tour.id, orderIds: [o.id] });
  const est = await earnings.estimate(tour.id);
  assert.ok(est.amount > 0, 'rémunération estimée affichée avant la tournée');
  await tours.start(courier, { tourId: tour.id });
  for (const s of await tours.stopsOf(tour.id)) await tours.submitStop(courier, { stopId: s.id });
  await tours.close(courier, { tourId: tour.id });

  const e = await store.get('TourEarning', tour.id);
  assert.equal(e.status, 'TO_VALIDATE');
  assert.equal(e.amount, est.amount, 'payé sur le km estimé, comme annoncé');
  await assert.rejects(earnings.adjust(admin, { tourId: tour.id, amount: 3 }), /motif/);
  await assert.rejects(earnings.validate({ sub: 'd', groups: ['dispatch'] }, { tourId: tour.id }), /comptabilité/);
  const adj = await earnings.adjust(admin, { tourId: tour.id, amount: 3, reason: 'Attente au dépôt' });
  assert.equal(adj.amount, Math.round((est.amount + 3) * 100) / 100);
  await assert.rejects(earnings.markPaid(admin, { courierId: courier.sub, month: '2026-11' }), /Validez/);
  await earnings.validate(admin, { tourId: tour.id });
  assert.equal((await store.get('Tour', tour.id)).status, 'VALIDATED');
  const mine = await earnings.myEarnings(courier, { month: '2026-11' });
  assert.equal(mine.status, 'VALIDATED');
  assert.deepEqual(mine.days, [{ date: '2026-11-04', amount: adj.amount }]);
  await assert.rejects(earnings.statement({ sub: 'autre', groups: ['livreur'] }, { courierId: courier.sub, month: '2026-11' }), /introuvable/);
  const paid = await earnings.markPaid(admin, { courierId: courier.sub, month: '2026-11' });
  assert.equal(paid.status, 'PAID');
  await assert.rejects(earnings.adjust(admin, { tourId: tour.id, amount: 1, reason: 'x' }), /déjà payée/);
  const csv = await earnings.exportCsv(admin, { month: '2026-11', courierIds: [courier.sub] });
  const [head, line] = csv.split('\r\n');
  assert.equal(head, 'Livreur;Mois;Tournées;Kilomètres;Montant (€);Statut;Payé le');
  assert.match(line, /^Steeve;2026-11;1;[\d,]+;[\d,]+;Payé;2026-11-04$/);
});

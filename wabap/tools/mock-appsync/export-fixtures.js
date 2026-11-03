// Exporte des réponses réelles de deliveryApi (scénario de démonstration) pour les tests de contrat de l'app.
//   node export-fixtures.js ../../mobile/test/fixtures
const fs = require('fs');
const path = require('path');
const FN = path.join(__dirname, '../../mobile/amplify/backend/function/deliveryApi');
const { handle, buildServices } = require(path.join(FN, 'src/index'));
const { createMemoryStore } = require(path.join(FN, 'test/memoryStore'));
const seed = require('./seed');

(async () => {
  const out = process.argv[2];
  const store = createMemoryStore();
  const services = buildServices({ store, labelSecret: 's', geocoder: seed.geocoder, stripe: seed.stripe, files: { put: async (k) => ({ key: k, url: `https://exemple/${k}` }) }, mailer: { send: async () => {} }, config: { tzOffsetMinutes: -240 } });
  await seed.run(services, store);
  const call = (fieldName, args, identity) => handle({ fieldName, arguments: args, identity }, services);
  const steeve = { sub: 'livreur-steeve', groups: ['livreur'] };
  const tours = await store.query('Tour', 'byCourier', 'courierId', steeve.sub);
  const running = tours.find((t) => t.status === 'IN_PROGRESS');
  const write = (name, json) => fs.writeFileSync(path.join(out, `${name}.json`), JSON.stringify(JSON.parse(json), null, 2));
  write('courier_tour_view', await call('courierTourView', { tourId: running.id }, steeve));
  const course = [...store.tables.Order.values()].find((o) => o.billingMode === 'PER_ORDER');
  write('order_tracking', await call('orderTracking', { orderId: course.id }, { sub: course.ownerSub, groups: [] }));
  write('quote', await call('quoteCourse', { input: JSON.stringify({
    pickup: { address: { formatted: 'A', street: 'A', latitude: 14.6026, longitude: -61.0705 } },
    delivery: { address: { formatted: 'B', street: 'B', latitude: 14.645, longitude: -61.088 } }, size: 'M', maxDays: 1,
  }) }, { sub: 'x', groups: [] }));
  const karim = { sub: 'livreur-karim', groups: ['livreur'] };
  const earned = [...store.tables.TourEarning.values()][0];
  write('my_earnings', await call('myEarnings', { month: earned.month }, karim));
  console.log('fixtures écrites dans', out);
})();

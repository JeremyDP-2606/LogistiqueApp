/* Amplify Params - DO NOT EDIT
	ENV
	REGION
Amplify Params - DO NOT EDIT */
// Résolveur AppSync (@function) de la plateforme : demandes, colis, tournées, preuves,
// courses, étiquettes, rémunération. Également appelée par la tâche planifiée d'envoi des étiquettes.
const { createDynamoStore } = require('./lib/store');
const { createOrders, UserError } = require('./lib/orders');
const { createTours } = require('./lib/tours');
const { createCourses } = require('./lib/courses');
const { createLabels } = require('./lib/labelsService');
const { createEarnings } = require('./lib/earnings');
const { createStripe } = require('./lib/stripe');
const { createGoogle } = require('./lib/google');
const { createFiles, createMailer } = require('./lib/aws');
const { getSecret } = require('./secrets');

function buildServices(ctx) {
  const orders = createOrders(ctx);
  const tours = createTours(ctx, orders);
  const courses = createCourses(ctx, orders, tours);
  const labels = createLabels(ctx, orders);
  const earnings = createEarnings(ctx);
  ctx.hooks = { onOrderStatus: courses.onOrderStatus, onTourClosed: earnings.onTourClosed };
  return { orders, tours, courses, labels, earnings };
}

let services;
async function getServices() {
  if (services) return services;
  for (const v of ['GRAPHQL_API_ID', 'STORAGE_BUCKET']) if (!process.env[v]) throw new Error(`${v} manquant`);
  const region = process.env.REGION;
  const google = createGoogle({ getKey: () => getSecret('GOOGLE_MAPS_API_KEY') });
  const files = createFiles({ bucket: process.env.STORAGE_BUCKET, region });
  services = buildServices({
    store: createDynamoStore({ apiId: process.env.GRAPHQL_API_ID, env: process.env.ENV, region }),
    geocoder: google,
    router: google,
    stripe: createStripe({ getKey: () => getSecret('STRIPE_SECRET_KEY') }),
    labelSecret: await getSecret('LABEL_SIGNING_SECRET'),
    files,
    mailer: createMailer({ region, from: process.env.SENDER_EMAIL, files }),
    config: {
      tzOffsetMinutes: Number(process.env.TZ_OFFSET_MINUTES || -240),
      distanceAlertMeters: Number(process.env.DISTANCE_ALERT_METERS || 200),
      maxAddDetourKm: Number(process.env.MAX_ADD_DETOUR_KM || 3),
    },
    log: console,
  });
  return services;
}

const json = (v) => (typeof v === 'string' ? JSON.parse(v) : v);

// Opération GraphQL → fonction métier
const OPERATIONS = {
  // Demandes
  ingestOrder: (s, id, a) => s.orders.ingest(id, { customerId: a.customerId, source: a.source, connectorId: a.connectorId, record: json(a.record) }),
  ingestOrders: async (s, id, a) => {
    const records = json(a.records);
    const results = [];
    for (const record of records) results.push(await s.orders.ingest(id, { customerId: a.customerId, source: a.source || 'IMPORT', connectorId: a.connectorId, record }));
    return JSON.stringify({
      total: results.length,
      ready: results.filter((o) => o.status === 'CREATED').length,
      toFix: results.filter((o) => o.status === 'TO_FIX').map((o) => ({ id: o.id, ref: o.ref, anomalies: o.anomalies })),
    });
  },
  fixOrder: (s, id, a) => s.orders.fix(id, { orderId: a.orderId, patch: json(a.patch) }),
  parcelHistory: async (s, id, a) => JSON.stringify(await s.orders.history(a.parcelId)),
  // Courses
  quoteCourse: async (s, id, a) => JSON.stringify((({ price, deadlineAt }) => ({ ...price, deadlineAt }))(await s.courses.quote(id, json(a.input)))),
  createCourse: async (s, id, a) => JSON.stringify(await s.courses.create(id, json(a.input))),
  confirmCoursePayment: (s, id, a) => s.courses.confirmPayment(id, a),
  cancelOrder: (s, id, a) => s.courses.cancel(id, a),
  commercialGesture: (s, id, a) => s.courses.gesture(id, a),
  orderTracking: async (s, id, a) => JSON.stringify(await s.courses.clientView(id, a)),
  // Tournées
  createTour: (s, id, a) => s.tours.createTour(id, json(a.input)),
  addOrdersToTour: (s, id, a) => s.tours.addOrders(id, a),
  removeOrderFromTour: (s, id, a) => s.tours.removeOrder(id, a),
  lockStop: (s, id, a) => s.tours.lockStop(id, a),
  optimizeTour: (s, id, a) => s.tours.optimize(id, a),
  assignTour: (s, id, a) => s.tours.assign(id, a),
  acceptTour: (s, id, a) => s.tours.accept(id, a),
  startTour: (s, id, a) => s.tours.start(id, a),
  closeTour: (s, id, a) => s.tours.close(id, a),
  courierTourView: async (s, id, a) => JSON.stringify(await s.tours.courierView(id, a)),
  clientTourView: async (s, id, a) => JSON.stringify(await s.tours.clientView(id, a)),
  scanParcel: async (s, id, a) => JSON.stringify(await s.tours.scan(id, a)),
  submitStop: (s, id, a) => s.tours.submitStop(id, json(a.input)),
  failStop: (s, id, a) => s.tours.failStop(id, json(a.input)),
  updateCourierPosition: (s, id, a) => s.tours.recordPosition(id, a),
  // Étiquettes et statistiques
  generateLabels: async (s, id, a) => JSON.stringify(await s.labels.generate(id, a)),
  commentStats: async (s, id, a) => JSON.stringify(await s.labels.commentStats(id, a)),
  // Rémunération
  tourEarningEstimate: async (s, id, a) => JSON.stringify(await s.earnings.estimate(a.tourId)),
  adjustEarning: (s, id, a) => s.earnings.adjust(id, a),
  validateEarning: (s, id, a) => s.earnings.validate(id, a),
  courierStatement: async (s, id, a) => JSON.stringify(await s.earnings.statement(id, a)),
  markStatementPaid: async (s, id, a) => JSON.stringify(await s.earnings.markPaid(id, a)),
  exportStatementsCsv: (s, id, a) => s.earnings.exportCsv(id, a),
  myEarnings: async (s, id, a) => JSON.stringify(await s.earnings.myEarnings(id, a)),
};

function identityFrom(event) {
  const id = event.identity || {};
  const claims = id.claims || {};
  if (!id.sub && !claims.sub) throw new UserError('Authentification requise');
  return {
    sub: id.sub || claims.sub,
    groups: id.groups || claims['cognito:groups'] || [],
    name: claims.given_name || claims.name || null,
    email: claims.email || null,
    phone: claims.phone_number || null,
    clientName: claims['custom:clientName'] || null,
  };
}

async function handle(event, svc) {
  // Tâche planifiée (EventBridge) : envoi automatique des étiquettes aux clients B2B
  if (event.source === 'aws.events' || event.task === 'sendDueLabels') return svc.labels.sendDue();
  const op = OPERATIONS[event.fieldName];
  if (!op) throw new Error(`Opération inconnue : ${event.fieldName}`);
  try {
    return await op(svc, identityFrom(event), event.arguments || {});
  } catch (e) {
    if (e instanceof UserError) throw e;
    console.error(`${event.fieldName} :`, e);
    throw new Error('Erreur serveur, réessayez dans un instant');
  }
}

exports.handler = async (event) => handle(event, await getServices());
exports.handle = handle;
exports.buildServices = buildServices;
exports.OPERATIONS = OPERATIONS;

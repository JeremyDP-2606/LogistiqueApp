// Requêtes GraphQL du back-office (modèles AppSync et opérations de la fonction deliveryApi).
const ADDRESS = 'formatted number street complement postalCode city country latitude longitude';
const POINT = `address { ${ADDRESS} } contact { name phone email } instructions`;
export const ORDER = `id ref customerId customerName source externalRef status pickup { ${POINT} } delivery { ${POINT} }
  parcelCount size weightKg fragile deadlineAt hardConstraint maxDays priority proofProfileId billingMode
  anomalies { code field message } tourId priceTotal paymentStatus paidAt refundedAmount cancelReason createdAt updatedAt`;
export const TOUR = `id ref name date slot startTime start { ${ADDRESS} } courierId status dedicatedCustomerId orderIds customerIds
  estimatedKm estimatedMinutes alerts { stopId code message } notices { at message } incidents { parcelId customerId motive status }
  startedAt closedAt createdAt updatedAt`;
export const STOP = `id tourId sequence type customerId address { ${ADDRESS} } contact { name phone } instructions orderIds parcelIds
  deadlineAt windowStart windowEnd hard locked eta legKm status doneAt failureReason distanceMeters distanceAlert`;

export const Q = {
  ordersByStatus: `query($status: OrderStatus!, $nextToken: String) {
    ordersByStatus(status: $status, sortDirection: DESC, limit: 200, nextToken: $nextToken) { items { ${ORDER} } nextToken } }`,
  ordersByCustomer: `query($customerId: String!) { ordersByCustomer(customerId: $customerId, sortDirection: DESC, limit: 200) { items { ${ORDER} } } }`,
  getOrder: `query($id: ID!) { getOrder(id: $id) { ${ORDER} rawInput parcels { items { id code index total status labelStatus tourId } } } }`,
  parcelHistory: 'query($parcelId: ID!) { parcelHistory(parcelId: $parcelId) }',
  toursByStatus: `query($status: TourStatus!) { toursByStatus(status: $status, sortDirection: DESC, limit: 200) { items { ${TOUR} } } }`,
  getTour: `query($id: ID!) { getTour(id: $id) { ${TOUR} stops(limit: 500) { items { ${STOP} } } } }`,
  tourEarningEstimate: 'query($tourId: ID!) { tourEarningEstimate(tourId: $tourId) }',
  listCustomers: 'query { listCustomers(limit: 500) { items { id name customerTypeId billingMode labelMode dedicated proofProfileId defaults labelEmail { enabled emails leadHours } tracking { route showEta showStopsBefore showLivePosition } } } }',
  listCustomerTypes: 'query { listCustomerTypes(limit: 200) { items { id name proofProfileId } } }',
  listProofProfiles: 'query { listProofProfiles(limit: 200) { items { id name pickup { scan photo signature geoloc otp } delivery { scan photo signature geoloc otp } } } }',
  listCommentPresets: 'query { listCommentPresets(limit: 500) { items { id label kind clientVisible mandatory active } } }',
  listConnectors: 'query { listConnectors(limit: 200) { items { id customerId name kind mapping } } }',
  listPriceGrids: 'query { listPriceGrids(limit: 200) { items { id kind effectiveFrom status sizes delayCoefs minimum options vatRate proofProfileId } } }',
  listRateGrids: 'query { listRateGrids(limit: 200) { items { id kind effectiveFrom status rates nightStart nightEnd perStop perParcel minimumPerTour weekendPercent heavyParcelKg heavyParcelBonus splitRule } } }',
  listCourierProfiles: 'query { listCourierProfiles(limit: 500) { items { id name phone siret vehicle validated } } }',
  earningsToValidate: 'query { listTourEarnings(filter: { status: { eq: TO_VALIDATE } }, limit: 500) { items { id tourId tourRef courierId date km amount lines adjustments { amount reason at } status } } }',
  courierStatement: 'query($courierId: ID!, $month: String!) { courierStatement(courierId: $courierId, month: $month) }',
  exportStatementsCsv: 'query($month: String!, $courierIds: [ID!]!) { exportStatementsCsv(month: $month, courierIds: $courierIds) }',
  commentStats: 'query($from: AWSDate!, $to: AWSDate!) { commentStats(from: $from, to: $to) }',
};

export const M = {
  ingestOrder: `mutation($customerId: String, $source: OrderSource!, $connectorId: ID, $record: AWSJSON!) {
    ingestOrder(customerId: $customerId, source: $source, connectorId: $connectorId, record: $record) { ${ORDER} } }`,
  ingestOrders: `mutation($customerId: String, $source: OrderSource, $connectorId: ID, $records: AWSJSON!) {
    ingestOrders(customerId: $customerId, source: $source, connectorId: $connectorId, records: $records) }`,
  fixOrder: `mutation($orderId: ID!, $patch: AWSJSON!) { fixOrder(orderId: $orderId, patch: $patch) { ${ORDER} } }`,
  cancelOrder: `mutation($orderId: ID!, $reason: String) { cancelOrder(orderId: $orderId, reason: $reason) { ${ORDER} } }`,
  commercialGesture: `mutation($orderId: ID!, $amount: Float!, $reason: String!) { commercialGesture(orderId: $orderId, amount: $amount, reason: $reason) { ${ORDER} } }`,
  createTour: `mutation($input: AWSJSON!) { createTour(input: $input) { ${TOUR} } }`,
  addOrdersToTour: `mutation($tourId: ID!, $orderIds: [ID!]!) { addOrdersToTour(tourId: $tourId, orderIds: $orderIds) { ${TOUR} } }`,
  removeOrderFromTour: `mutation($tourId: ID!, $orderId: ID!, $reason: String) { removeOrderFromTour(tourId: $tourId, orderId: $orderId, reason: $reason) { ${TOUR} } }`,
  lockStop: `mutation($stopId: ID!, $locked: Boolean!) { lockStop(stopId: $stopId, locked: $locked) { id locked } }`,
  optimizeTour: `mutation($tourId: ID!) { optimizeTour(tourId: $tourId) { ${TOUR} } }`,
  assignTour: `mutation($tourId: ID!, $courierId: ID!) { assignTour(tourId: $tourId, courierId: $courierId) { ${TOUR} } }`,
  closeTour: `mutation($tourId: ID!, $reason: String) { closeTour(tourId: $tourId, reason: $reason) { ${TOUR} } }`,
  generateLabels: 'mutation($tourId: ID, $orderId: ID, $customerId: String, $extraCount: Int) { generateLabels(tourId: $tourId, orderId: $orderId, customerId: $customerId, extraCount: $extraCount) }',
  adjustEarning: 'mutation($tourId: ID!, $amount: Float!, $reason: String!) { adjustEarning(tourId: $tourId, amount: $amount, reason: $reason) { id amount status adjustments { amount reason at } } }',
  validateEarning: 'mutation($tourId: ID!) { validateEarning(tourId: $tourId) { id status } }',
  markStatementPaid: 'mutation($courierId: ID!, $month: String!) { markStatementPaid(courierId: $courierId, month: $month) }',
};

// Mutations générées pour la configuration (éditée directement par les équipes Wabap)
export const save = (model, fields) => ({
  create: `mutation($input: Create${model}Input!) { create${model}(input: $input) { ${fields} } }`,
  update: `mutation($input: Update${model}Input!) { update${model}(input: $input) { ${fields} } }`,
  remove: `mutation($input: Delete${model}Input!) { delete${model}(input: $input) { id } }`,
});

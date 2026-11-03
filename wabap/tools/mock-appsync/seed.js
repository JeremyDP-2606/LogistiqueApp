// Scénario de démonstration (Martinique), créé exclusivement par la logique métier de deliveryApi.
// Noms de clients et de personnes fictifs.

// Adresses de Fort-de-France et environs, avec coordonnées réelles approximatives
const PLACES = {
  'zone de la jambette': [14.6160, -61.0300, '97232', 'Le Lamentin'],
  'rue victor hugo': [14.6037, -61.0731, '97200', 'Fort-de-France'],
  'route de didier': [14.6280, -61.0800, '97200', 'Fort-de-France'],
  'boulevard du général de gaulle': [14.6070, -61.0680, '97200', 'Fort-de-France'],
  'rue lamartine': [14.6050, -61.0700, '97200', 'Fort-de-France'],
  'route de redoute': [14.6340, -61.0760, '97200', 'Fort-de-France'],
  'rue de la république': [14.6026, -61.0705, '97200', 'Fort-de-France'],
  'avenue des caraïbes': [14.6045, -61.0655, '97200', 'Fort-de-France'],
  'route de balata': [14.6450, -61.0880, '97200', 'Fort-de-France'],
  'quartier bellevue': [14.6150, -61.0830, '97200', 'Fort-de-France'],
  'schoelcher': [14.6150, -61.0950, '97233', 'Schœlcher'],
  'rue ernest deproge': [14.6010, -61.0690, '97200', 'Fort-de-France'],
  'cluny': [14.6190, -61.0740, '97200', 'Fort-de-France'],
};
const geocoder = {
  async geocode(q) {
    const key = Object.keys(PLACES).find((k) => q.toLowerCase().includes(k));
    if (!key) return null;
    const [latitude, longitude, postalCode, city] = PLACES[key];
    return { latitude, longitude, postalCode, city, formatted: q, quality: 'ROOFTOP' };
  },
};
const stripe = {
  async createPayment({ orderId }) { return { id: `pi_demo_${orderId.slice(0, 8)}`, client_secret: 'demo', status: 'succeeded' }; },
  async retrieve(id) { return { id, status: 'succeeded' }; },
  async refund() { return { id: 're_demo' }; },
};

const admin = { sub: 'admin-demo', groups: ['admin'], name: 'Admin' };
const couriers = [
  { sub: 'livreur-steeve', name: 'Steeve Charlery', phone: '+596696112233', siret: '901 234 567 00012', vehicle: 'Utilitaire' },
  { sub: 'livreur-lea', name: 'Léa Marie-Sainte', phone: '+596696445566', siret: '902 345 678 00015', vehicle: 'Scooter' },
  { sub: 'livreur-karim', name: 'Karim Bellance', phone: '+596696778899', siret: '903 456 789 00018', vehicle: 'Voiture' },
];
const asCourier = (c) => ({ sub: c.sub, groups: ['livreur'], name: c.name });

const localIso = (dayOffset, hhmm) => {
  const d = new Date(Date.now() - 4 * 3600000);
  d.setUTCDate(d.getUTCDate() + dayOffset);
  const day = d.toISOString().slice(0, 10);
  return { day, iso: new Date(`${day}T${hhmm}:00-04:00`).toISOString() };
};

async function run(s, store) {
  const at = new Date().toISOString();
  const put = (model, item) => store.put(model, { __typename: model, createdAt: at, updatedAt: at, ...item });

  // ---------- Configuration ----------
  await put('ProofProfile', { id: 'standard', name: 'Standard', pickup: { scan: true }, delivery: { geoloc: true, photo: true } });
  await put('ProofProfile', { id: 'securise', name: 'Sécurisé', pickup: { scan: true }, delivery: { scan: true, signature: true, geoloc: true } });
  await put('ProofProfile', { id: 'course', name: 'Course ponctuelle', pickup: { scan: true }, delivery: { photo: true, otp: true } });
  await put('CustomerType', { id: 'grand-compte', name: 'Grand compte', proofProfileId: 'standard' });
  await put('CustomerType', { id: 'pme', name: 'PME', proofProfileId: 'standard' });
  await put('CustomerType', { id: 'particulier', name: 'Particulier' });
  await put('Customer', {
    id: 'ENSEIGNE', name: 'Enseigne Caraïbes', customerTypeId: 'grand-compte', billingMode: 'ACCOUNT', labelMode: 'STRICT', dedicated: false,
    defaults: JSON.stringify({ parcelCount: 1, size: 'M', pickupAddress: 'Zone de la Jambette, 97232 Le Lamentin', pickupName: 'Entrepôt Enseigne Caraïbes' }),
    labelEmail: { enabled: true, emails: ['logistique@enseigne-caraibes.example'], leadHours: 24 },
    tracking: { route: 'NONE', showEta: true, showStopsBefore: true, showLivePosition: true },
  });
  await put('Customer', { id: 'GARAGE', name: 'Garage Lamartine', customerTypeId: 'pme', billingMode: 'ACCOUNT', labelMode: 'FLEXIBLE', proofProfileId: 'securise',
    labelEmail: { enabled: false, emails: [], leadHours: 6 }, tracking: { route: 'NONE', showLivePosition: true } });
  await put('Customer', { id: 'PHARMACIE', name: 'Pharmacie de la Savane', customerTypeId: 'pme', billingMode: 'ACCOUNT', labelMode: 'FLEXIBLE',
    defaults: JSON.stringify({ size: 'S', pickupAddress: 'Rue de la République, 97200 Fort-de-France', pickupName: 'Pharmacie de la Savane' }) });
  await put('Connector', {
    id: 'api-enseigne', customerId: 'ENSEIGNE', name: 'API Enseigne Caraïbes', kind: 'API',
    mapping: JSON.stringify({ externalRef: 'num_commande', deliveryName: 'client', deliveryPhone: 'tel', deliveryAddress: ['numero', 'voie', 'cp', 'ville'], instructions: 'commentaire', parcelCount: 'nb_colis' }),
  });
  for (const [id, kind, label, clientVisible, mandatory] of [
    ['gardien', 'DELIVERY', 'Laissé au gardien', true, false],
    ['bal', 'DELIVERY', 'Déposé en boîte aux lettres', true, false],
    ['acces', 'DELIVERY', 'Accès difficile', false, false],
    ['abime', 'PICKUP', 'Colis abîmé à la collecte', true, false],
    ['absent', 'FAILURE', 'Destinataire absent', true, true],
    ['introuvable', 'FAILURE', 'Adresse introuvable', true, true],
    ['refuse', 'FAILURE', 'Colis refusé', true, true],
  ]) await put('CommentPreset', { id, kind, label, clientVisible, mandatory, active: 'yes' });
  await put('PriceGrid', {
    id: 'grille-2026', kind: 'COURSE', status: 'PUBLISHED', effectiveFrom: '2026-01-01T04:00:00.000Z', minimum: 10, vatRate: 0.085, proofProfileId: 'course',
    sizes: JSON.stringify({ S: { base: 5, perKm: 0.8, maxWeightKg: 2 }, M: { base: 7, perKm: 1, maxWeightKg: 10 }, L: { base: 10, perKm: 1.3, maxWeightKg: 25 }, XL: { base: 15, perKm: 1.8, maxWeightKg: 50 } }),
    delayCoefs: JSON.stringify({ 1: 1.5, 2: 1.2, 3: 1 }), options: JSON.stringify({ deadline: 5, reinforcedProof: 3, nightPercent: 20, weekendPercent: 15 }),
  });
  await put('RateGrid', {
    id: 'remu-2026', kind: 'COURIER', status: 'PUBLISHED', effectiveFrom: '2026-01-01T04:00:00.000Z',
    rates: JSON.stringify({ default: { DAY: 0.6, NIGHT: 0.8 }, 'grand-compte': { DAY: 0.55, NIGHT: 0.75 }, pme: { DAY: 0.65, NIGHT: 0.85 } }),
    nightStart: '21:00', nightEnd: '06:00', perStop: 0.5, perParcel: 0, minimumPerTour: 25, weekendPercent: 10, heavyParcelKg: 25, heavyParcelBonus: 2, splitRule: 'POINTS',
  });
  for (const c of couriers) await put('CourierProfile', { id: c.sub, name: c.name, phone: c.phone, siret: c.siret, vehicle: c.vehicle, validated: true });

  // ---------- Demandes ----------
  const ens = (n, nom, voie, extra = {}) => s.orders.ingest(admin, { customerId: 'ENSEIGNE', source: 'API', connectorId: 'api-enseigne', record: {
    num_commande: `EC-${4810 + n}`, client: nom, tel: `0696 ${String(200000 + n * 1111).slice(0, 2)} ${String(30 + n)} ${String(40 + n)}`, numero: String(n * 3 + 2), voie, cp: '97200', ville: 'Fort-de-France', commentaire: '', nb_colis: n % 3 === 0 ? 2 : 1, ...extra,
  } });
  const o = {};
  o.e1 = await ens(1, 'JOSEPH MARIE-LINE', 'Rue Victor Hugo', { commentaire: '2e étage, code 4521' });
  o.e2 = await ens(2, 'ALEXIS DORVAL', 'Route de Didier');
  o.e3 = await ens(3, 'SANDRINE CÉLESTE', 'Boulevard du Général de Gaulle');
  o.e4 = await ens(4, 'PATRICK MONTOUT', 'Route de Redoute');
  o.e5 = await ens(5, 'NADIA EUGÈNE', 'Avenue des Caraïbes');
  o.e6 = await ens(6, 'FABRICE LOUISY', 'Route de Balata');
  o.e7 = await ens(7, 'CORINNE THÉODOSE', 'Quartier Bellevue');
  o.bad1 = await ens(8, 'MARC ÉLISABETH', 'Impasse des Flamboyants', { tel: '06 12' });
  o.bad2 = await ens(1, 'JOSEPH MARIE-LINE', 'Rue Victor Hugo'); // doublon de EC-4811
  o.g1 = await s.orders.ingest(admin, { customerId: 'GARAGE', source: 'MANUAL', record: {
    pickupAddress: '14 rue Lamartine, 97200 Fort-de-France', pickupName: 'Garage Lamartine', pickupPhone: '0596 60 11 22',
    deliveryAddress: 'Cluny, 97200 Fort-de-France', deliveryName: 'Carrosserie Cluny', deliveryPhone: '0696 50 60 70', instructions: 'Pièce : rétroviseur', size: 'L', weightKg: 6,
  } });
  o.p1 = await s.orders.ingest(admin, { customerId: 'PHARMACIE', source: 'MANUAL', record: {
    deliveryAddress: '7 rue Ernest Deproge, 97200 Fort-de-France', deliveryName: 'Mme Rosette', deliveryPhone: '0696 70 80 90',
    deadlineAt: localIso(0, '12:00').iso, hardConstraint: true,
  } });
  o.p2 = await s.orders.ingest(admin, { customerId: 'PHARMACIE', source: 'MANUAL', record: {
    deliveryAddress: 'Schoelcher, 97233 Schœlcher', deliveryName: 'M. Valère', deliveryPhone: '0696 12 21 12',
  } });
  // Course ponctuelle d'un particulier, payée : prête à planifier
  const particulier = { sub: 'part-demo', groups: [], name: 'Jessica', email: 'jessica@exemple.fr' };
  const course = await s.courses.create(particulier, {
    pickup: { address: { formatted: '3 rue de la République, 97200 Fort-de-France', street: 'rue de la République', latitude: 14.6026, longitude: -61.0705 }, name: 'Jessica', phone: '0696 33 44 55' },
    delivery: { address: { formatted: 'Route de Balata, 97200 Fort-de-France', street: 'Route de Balata', latitude: 14.6450, longitude: -61.0880 }, name: 'Grand-mère Lucie', phone: '0596 64 00 00' },
    size: 'S', maxDays: 2,
  });
  await s.courses.confirmPayment(particulier, { orderId: course.order.id });

  // ---------- Tournées ----------
  const depot = { formatted: 'Dépôt Wabap, Zone de la Jambette, Le Lamentin', latitude: 14.6150, longitude: -61.0320 };
  const [steeve, lea, karim] = couriers;

  // Hier : tournée terminée, rémunération à valider
  const y = localIso(-1, '07:00');
  const tY = await s.tours.createTour(admin, { name: 'Pharmacie · matin', date: y.day, slot: 'DAY', startTime: y.iso, start: depot, courierId: karim.sub });
  await s.tours.addOrders(admin, { tourId: tY.id, orderIds: [o.p2.id] });
  await s.tours.start(asCourier(karim), { tourId: tY.id });
  for (const st of await s.tours.stopsOf(tY.id)) {
    const p = await store.get('Parcel', st.parcelIds[0]);
    await s.tours.submitStop(asCourier(karim), { stopId: st.id, scannedCodes: st.type === 'PICKUP' ? [p.code] : [], proofs: { photoKeys: ['preuves/boite.jpg'] }, position: st.address, comment: st.type === 'DELIVERY' ? { presetId: 'bal' } : undefined });
  }
  await s.tours.close(asCourier(karim), { tourId: tY.id });

  // Aujourd'hui matin : tournée mutualisée en cours
  const m = localIso(0, '06:30');
  const tM = await s.tours.createTour(admin, { name: 'Fort-de-France · matin', date: m.day, slot: 'DAY', startTime: m.iso, start: depot, courierId: steeve.sub });
  await s.tours.addOrders(admin, { tourId: tM.id, orderIds: [o.e1.id, o.e2.id, o.e3.id, o.e4.id, o.g1.id, o.p1.id] });
  await s.orders.createParcels({ id: null, customerId: 'ENSEIGNE', size: 'M' }, 5, { reservedForTour: tM.id });
  await s.tours.start(asCourier(steeve), { tourId: tM.id });
  const stops = await s.tours.stopsOf(tM.id);
  const codesAt = async (st) => Promise.all(st.parcelIds.map(async (id) => (await store.get('Parcel', id)).code));
  let done = 0;
  let deliveries = 0;
  for (const st of stops) {
    if (done >= 6) break;
    if (st.type === 'DELIVERY') deliveries++;
    if (st.type === 'PICKUP') {
      await s.tours.submitStop(asCourier(steeve), { stopId: st.id, scannedCodes: await codesAt(st), position: st.address, deviceId: 'android-steeve' });
    } else if (deliveries === 3) {
      await s.tours.failStop(asCourier(steeve), { stopId: st.id, comment: { presetId: 'absent', text: 'Personne au portail, voisin injoignable' }, proofs: { photoKeys: ['preuves/portail.jpg'] }, position: st.address });
    } else {
      const customer = await store.get('Customer', st.customerId);
      const secure = customer.proofProfileId === 'securise';
      const off = deliveries === 2 ? { latitude: st.address.latitude + 0.004, longitude: st.address.longitude } : st.address;
      await s.tours.submitStop(asCourier(steeve), {
        stopId: st.id, scannedCodes: secure ? await codesAt(st) : [], position: off, deviceId: 'android-steeve',
        proofs: { photoKeys: ['preuves/depot.jpg'], signatureKey: secure ? 'preuves/sig.png' : undefined, signerName: secure ? 'M. Carrosserie' : undefined },
        comment: deliveries === 1 ? { presetId: 'gardien', text: 'Gardien très aimable' } : undefined,
      });
    }
    done++;
  }
  await s.tours.recordPosition(asCourier(steeve), { latitude: 14.6110, longitude: -61.0700 });

  // Aujourd'hui après-midi : tournée mutualisée attribuée à Léa (la démo y insère une course)
  const a = localIso(0, '14:00');
  const tA = await s.tours.createTour(admin, { name: 'Fort-de-France · après-midi', date: a.day, slot: 'DAY', startTime: a.iso, start: depot, courierId: lea.sub });
  await s.tours.addOrders(admin, { tourId: tA.id, orderIds: [o.e5.id, o.e6.id] });

  // Brouillon pour demain
  const d = localIso(1, '05:30');
  await s.tours.createTour(admin, { name: 'Tournée de nuit', date: d.day, slot: 'NIGHT', startTime: localIso(1, '04:00').iso, start: depot });

  return `Scénario : ${Object.keys(o).length + 1} demandes, 4 tournées, ${couriers.length} livreurs`;
}

module.exports = { run, geocoder, stripe };

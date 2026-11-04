// Wabap V2 : courses à la demande et grilles tarifaires.
import { API, graphqlOperation } from "@/api/client";

const STOP = "address latitude longitude contactName phone instructions";
const COURSE = `
  id ref status owner clientId clientName courierId courierName courierPhone courierVehicle
  pickup { ${STOP} } dropoff { ${STOP} }
  packageSize packageDescription urgency vehicle distanceKm etaMinutes
  priceHt priceTva priceTtc courierEarning paymentMode paymentIntentId paymentStatus
  reason ratingStars ratingComment createdAt updatedAt
`;

const run = async (query, variables = {}) => {
  const result = await API.graphql(graphqlOperation(query, variables));
  return result.data;
};

export const listCourses = async () => {
  const items = [];
  let nextToken = null;
  do {
    const data = await run(
      `query List($nextToken: String) { listCourses(limit: 500, nextToken: $nextToken) { items { ${COURSE} } nextToken } }`,
      { nextToken }
    );
    items.push(...data.listCourses.items);
    nextToken = data.listCourses.nextToken;
  } while (nextToken && items.length < 2000);
  return items.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
};

export const getCourse = async (id) => {
  const data = await run(
    `query Get($id: ID!) { getCourse(id: $id) { ${COURSE} events(limit: 100) { items { id status message latitude longitude createdAt } } } }`,
    { id }
  );
  const course = data.getCourse;
  if (course) course.events.items.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
  return course;
};

export const cancelCourse = async (courseId, reason) => {
  const data = await run(
    `mutation Cancel($courseId: ID!, $reason: String) { cancelCourse(courseId: $courseId, reason: $reason) { ${COURSE} } }`,
    { courseId, reason }
  );
  return data.cancelCourse;
};

const TARIF = "id vehicles expressMultiplier vatRate courierShare invoice updatedAt";

export const listTarifs = async () => {
  const data = await run(`query { listTarifs(limit: 200) { items { ${TARIF} } } }`);
  return data.listTarifs.items.map((t) => ({ ...t, vehicles: JSON.parse(t.vehicles) }));
};

export const saveTarif = async (tarif, exists) => {
  const input = {
    id: tarif.id,
    vehicles: JSON.stringify(tarif.vehicles),
    expressMultiplier: Number(tarif.expressMultiplier),
    vatRate: Number(tarif.vatRate),
    courierShare: Number(tarif.courierShare),
    invoice: Boolean(tarif.invoice),
  };
  const op = exists ? "updateTarif" : "createTarif";
  const input_t = exists ? "UpdateTarifInput" : "CreateTarifInput";
  const data = await run(`mutation Save($input: ${input_t}!) { ${op}(input: $input) { ${TARIF} } }`, { input });
  return data[op];
};

// Grille appliquée tant qu'aucune n'est enregistrée (identique à la Lambda courseApi)
export const DEFAULT_TARIF = {
  id: "default",
  vehicles: [
    { vehicle: "BIKE", base: 4.5, perKm: 1.1, maxKm: 8, maxSize: "M", speedKmh: 15 },
    { vehicle: "MOTORBIKE", base: 5.5, perKm: 1.3, maxKm: 15, maxSize: "M", speedKmh: 25 },
    { vehicle: "CAR", base: 8, perKm: 1.6, maxKm: 40, maxSize: "L", speedKmh: 30 },
    { vehicle: "VAN", base: 15, perKm: 2.2, maxKm: 80, maxSize: "XL", speedKmh: 28 },
  ],
  expressMultiplier: 1.4,
  vatRate: 0.2,
  courierShare: 0.8,
  invoice: false,
};

export const COURSE_STATUS = {
  AWAITING_PAYMENT: { label: "Paiement en attente", color: "grey" },
  PENDING: { label: "Recherche d'un livreur", color: "orange" },
  ASSIGNED: { label: "Livreur assigné", color: "blue" },
  PICKING_UP: { label: "Vers le retrait", color: "blue" },
  PICKED_UP: { label: "Colis récupéré", color: "blue" },
  DELIVERING: { label: "En livraison", color: "blue" },
  COMPLETED: { label: "Livrée", color: "green" },
  ISSUE: { label: "Problème", color: "red" },
  CANCELLED: { label: "Annulée", color: "grey" },
};

export const VEHICLES = { BIKE: "Vélo", MOTORBIKE: "Scooter", CAR: "Voiture", VAN: "Utilitaire" };

export const PAYMENT_STATUS = {
  awaiting_authorization: "Carte non encore autorisée",
  authorized: "Carte autorisée",
  captured: "Payé",
  cancelled: "Autorisation libérée",
  capture_failed: "Encaissement échoué",
  invoice: "Facturation mensuelle",
};

export const eur = (n) => new Intl.NumberFormat("fr-FR", { style: "currency", currency: "EUR" }).format(n ?? 0);
export const dateTime = (s) => new Date(s).toLocaleString("fr-FR", { dateStyle: "short", timeStyle: "short" });

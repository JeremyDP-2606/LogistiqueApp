// Tarification : distance (haversine × facteur route), véhicule, taille du colis, urgence.

const SIZES = ['S', 'M', 'L', 'XL'];

const VEHICLES = {
  bike:      { label: 'Vélo',        base: 4.5, perKm: 1.1, maxKm: 8,  maxSize: 'M',  speedKmh: 15 },
  motorbike: { label: 'Scooter',     base: 5.5, perKm: 1.3, maxKm: 15, maxSize: 'M',  speedKmh: 25 },
  car:       { label: 'Voiture',     base: 8,   perKm: 1.6, maxKm: 40, maxSize: 'L',  speedKmh: 22 },
  van:       { label: 'Utilitaire',  base: 15,  perKm: 2.2, maxKm: 80, maxSize: 'XL', speedKmh: 20 },
};

const URGENCY = {
  standard: { label: 'Standard (sous 2h)', multiplier: 1 },
  express:  { label: 'Express (sous 45 min)', multiplier: 1.4 },
};

const VAT_RATE = 0.2;
const COURIER_SHARE = 0.8;
const ROAD_FACTOR = 1.3; // la route est plus longue que la ligne droite

const round2 = (n) => Math.round(n * 100) / 100;

function haversineKm(a, b) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function roadDistanceKm(a, b) {
  return round2(haversineKm(a, b) * ROAD_FACTOR);
}

function vehicleFits(vehicle, size) {
  return SIZES.indexOf(size) <= SIZES.indexOf(VEHICLES[vehicle].maxSize);
}

function priceFor(vehicle, distanceKm, urgency = 'standard') {
  const v = VEHICLES[vehicle];
  const ht = round2((v.base + v.perKm * distanceKm) * URGENCY[urgency].multiplier);
  const tva = round2(ht * VAT_RATE);
  return { ht, tva, ttc: round2(ht + tva), currency: 'EUR' };
}

function quote({ pickup, dropoff, packageSize = 'S', urgency = 'standard' }) {
  const distanceKm = roadDistanceKm(pickup, dropoff);
  const options = Object.entries(VEHICLES)
    .filter(([key, v]) => vehicleFits(key, packageSize) && distanceKm <= v.maxKm)
    .map(([key, v]) => ({
      vehicle: key,
      label: v.label,
      etaMinutes: Math.max(10, Math.round((distanceKm / v.speedKmh) * 60) + 10),
      price: priceFor(key, distanceKm, urgency),
    }))
    .sort((a, b) => a.price.ttc - b.price.ttc);
  return { distanceKm, packageSize, urgency, options };
}

function validPoint(p) {
  return p && Number.isFinite(p.lat) && Number.isFinite(p.lng) && Math.abs(p.lat) <= 90 && Math.abs(p.lng) <= 180;
}

module.exports = {
  SIZES, VEHICLES, URGENCY, COURIER_SHARE,
  haversineKm, roadDistanceKm, vehicleFits, priceFor, quote, validPoint, round2,
};

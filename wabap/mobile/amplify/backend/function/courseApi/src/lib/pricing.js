// Tarification des courses. La grille vient du modèle Tarif (modifiable dans le back-office) ;
// DEFAULT_TARIF s'applique tant qu'aucune grille n'est enregistrée.
const SIZES = ['S', 'M', 'L', 'XL'];

const DEFAULT_TARIF = {
  id: 'default',
  vehicles: [
    { vehicle: 'BIKE', base: 4.5, perKm: 1.1, maxKm: 8, maxSize: 'M', speedKmh: 15 },
    { vehicle: 'MOTORBIKE', base: 5.5, perKm: 1.3, maxKm: 15, maxSize: 'M', speedKmh: 25 },
    { vehicle: 'CAR', base: 8, perKm: 1.6, maxKm: 40, maxSize: 'L', speedKmh: 30 },
    { vehicle: 'VAN', base: 15, perKm: 2.2, maxKm: 80, maxSize: 'XL', speedKmh: 28 },
  ],
  expressMultiplier: 1.4,
  vatRate: 0.2,
  courierShare: 0.8,
};

const round2 = (n) => Math.round(n * 100) / 100;

function haversineKm(a, b) {
  const R = 6371;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLng = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function normalizeTarif(t) {
  if (!t) return DEFAULT_TARIF;
  const vehicles = typeof t.vehicles === 'string' ? JSON.parse(t.vehicles) : t.vehicles;
  return { ...DEFAULT_TARIF, ...t, vehicles: vehicles && vehicles.length ? vehicles : DEFAULT_TARIF.vehicles };
}

// route = { distanceKm, durationMin } (distance routière réelle) ; durationMin peut être null
function quote({ route, packageSize, urgency, tarif }) {
  const t = normalizeTarif(tarif);
  const mult = urgency === 'EXPRESS' ? t.expressMultiplier : 1;
  const distanceKm = round2(route.distanceKm);
  const options = t.vehicles
    .filter((v) => SIZES.indexOf(packageSize) <= SIZES.indexOf(v.maxSize) && distanceKm <= v.maxKm)
    .map((v) => {
      const priceHt = round2((v.base + v.perKm * distanceKm) * mult);
      const priceTva = round2(priceHt * t.vatRate);
      const drive = route.durationMin != null && v.vehicle !== 'BIKE'
        ? route.durationMin
        : (distanceKm / v.speedKmh) * 60;
      return {
        vehicle: v.vehicle,
        etaMinutes: Math.max(10, Math.round(drive) + 10),
        priceHt,
        priceTva,
        priceTtc: round2(priceHt + priceTva),
        courierEarning: round2(priceHt * t.courierShare),
      };
    })
    .sort((a, b) => a.priceTtc - b.priceTtc);
  return { distanceKm, options };
}

module.exports = { SIZES, DEFAULT_TARIF, quote, haversineKm, round2, normalizeTarif };

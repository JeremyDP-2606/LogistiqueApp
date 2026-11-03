// Calculs géographiques simples.
function distanceMeters(a, b) {
  const R = 6371000;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.latitude - a.latitude);
  const dLng = rad(b.longitude - a.longitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.latitude)) * Math.cos(rad(b.latitude)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// Distance routière estimée sans appel externe (le moteur d'itinéraire réel la remplace quand il est branché)
const ROAD_FACTOR = 1.3;
const roadKm = (a, b) => (distanceMeters(a, b) / 1000) * ROAD_FACTOR;

const round2 = (n) => Math.round(n * 100) / 100;

module.exports = { distanceMeters, roadKm, round2, ROAD_FACTOR };

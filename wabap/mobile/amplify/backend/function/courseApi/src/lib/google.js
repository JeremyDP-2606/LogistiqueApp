// Distance routière réelle via l'API Google Routes.
// En cas d'échec (quota, réseau), repli sur la distance à vol d'oiseau × 1,3 pour ne pas bloquer la commande.
const { haversineKm, round2 } = require('./pricing');

function createGoogle({ getKey, fetchImpl = fetch, log = console }) {
  async function route(pickup, dropoff) {
    try {
      const key = await getKey();
      const res = await fetchImpl('https://routes.googleapis.com/directions/v2:computeRoutes', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': key,
          'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration',
        },
        body: JSON.stringify({
          origin: { location: { latLng: { latitude: pickup.latitude, longitude: pickup.longitude } } },
          destination: { location: { latLng: { latitude: dropoff.latitude, longitude: dropoff.longitude } } },
          travelMode: 'DRIVE',
          routingPreference: 'TRAFFIC_AWARE',
        }),
      });
      if (!res.ok) throw new Error(`Google Routes ${res.status}`);
      const data = await res.json();
      const r = data.routes && data.routes[0];
      if (!r || !r.distanceMeters) throw new Error('Aucun itinéraire');
      return {
        distanceKm: round2(r.distanceMeters / 1000),
        durationMin: r.duration ? Math.round(parseInt(r.duration, 10) / 60) : null,
        source: 'google',
      };
    } catch (e) {
      log.warn(`Repli distance à vol d'oiseau : ${e.message}`);
      return { distanceKm: round2(haversineKm(pickup, dropoff) * 1.3), durationMin: null, source: 'estimate' };
    }
  }
  return { route };
}

module.exports = { createGoogle };

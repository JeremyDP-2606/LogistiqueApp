// Google Maps : géocodage (Geocoding API) et distance d'itinéraire (Routes API).
function createGoogle({ getKey, fetchImpl = fetch }) {
  async function geocode(address) {
    const key = await getKey();
    const url = `https://maps.googleapis.com/maps/api/geocode/json?language=fr&region=fr&address=${encodeURIComponent(address)}&key=${key}`;
    const res = await fetchImpl(url);
    if (!res.ok) throw new Error(`Géocodage ${res.status}`);
    const data = await res.json();
    const r = data.results && data.results[0];
    if (!r || r.partial_match && r.geometry.location_type === 'APPROXIMATE') return null; // trop imprécis : anomalie
    const comp = (type) => (r.address_components.find((c) => c.types.includes(type)) || {}).long_name || null;
    return {
      latitude: r.geometry.location.lat,
      longitude: r.geometry.location.lng,
      formatted: r.formatted_address,
      postalCode: comp('postal_code'),
      city: comp('locality'),
      quality: r.geometry.location_type,
    };
  }

  async function km(a, b) {
    const key = await getKey();
    const res = await fetchImpl('https://routes.googleapis.com/directions/v2:computeRoutes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': key, 'X-Goog-FieldMask': 'routes.distanceMeters' },
      body: JSON.stringify({
        origin: { location: { latLng: { latitude: a.latitude, longitude: a.longitude } } },
        destination: { location: { latLng: { latitude: b.latitude, longitude: b.longitude } } },
        travelMode: 'DRIVE',
      }),
    });
    if (!res.ok) throw new Error(`Itinéraire ${res.status}`);
    const r = (await res.json()).routes?.[0];
    if (!r) throw new Error('Aucun itinéraire');
    return r.distanceMeters / 1000;
  }

  return { geocode, km };
}

module.exports = { createGoogle };

// Geohash : découpe la carte en cellules pour retrouver les livreurs et les courses proches
// sans index géographique (DynamoDB n'en a pas).
// Précision 5 ≈ cellule de 4,9 km × 4,9 km ; précision 4 ≈ 39 km × 19,5 km.
const BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

function encode(lat, lng, precision = 5) {
  let latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  let hash = '', bit = 0, ch = 0, even = true;
  while (hash.length < precision) {
    if (even) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) { ch = (ch << 1) | 1; lngMin = mid; } else { ch <<= 1; lngMax = mid; }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) { ch = (ch << 1) | 1; latMin = mid; } else { ch <<= 1; latMax = mid; }
    }
    even = !even;
    if (++bit === 5) { hash += BASE32[ch]; bit = 0; ch = 0; }
  }
  return hash;
}

function bounds(hash) {
  let latMin = -90, latMax = 90, lngMin = -180, lngMax = 180, even = true;
  for (const c of hash) {
    const n = BASE32.indexOf(c);
    for (let i = 4; i >= 0; i--) {
      const b = (n >> i) & 1;
      if (even) { const mid = (lngMin + lngMax) / 2; if (b) lngMin = mid; else lngMax = mid; }
      else { const mid = (latMin + latMax) / 2; if (b) latMin = mid; else latMax = mid; }
      even = !even;
    }
  }
  return { latMin, latMax, lngMin, lngMax };
}

// La cellule et ses 8 voisines (un livreur au bord d'une cellule voit aussi celles d'à côté)
function neighborhood(hash) {
  const b = bounds(hash);
  const dLat = b.latMax - b.latMin, dLng = b.lngMax - b.lngMin;
  const cLat = (b.latMin + b.latMax) / 2, cLng = (b.lngMin + b.lngMax) / 2;
  const cells = new Set();
  for (const i of [-1, 0, 1]) {
    for (const j of [-1, 0, 1]) {
      const lat = Math.max(-89.999, Math.min(89.999, cLat + i * dLat));
      let lng = cLng + j * dLng;
      if (lng > 180) lng -= 360;
      if (lng < -180) lng += 360;
      cells.add(encode(lat, lng, hash.length));
    }
  }
  return [...cells];
}

module.exports = { encode, bounds, neighborhood };

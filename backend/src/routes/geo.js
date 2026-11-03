// Géocodage via Nominatim (OpenStreetMap). Respecter la politique d'usage :
// https://operations.osmfoundation.org/policies/nominatim/ — en production, utiliser un fournisseur dédié.
const express = require('express');
const { requireAuth } = require('../auth');

module.exports = function geoRoutes(db) {
  const r = express.Router();
  const cache = new Map();
  const UA = process.env.GEOCODER_USER_AGENT || 'LogistiqueApp/1.0';

  async function nominatim(path) {
    if (cache.has(path)) return cache.get(path);
    const resp = await fetch(`https://nominatim.openstreetmap.org/${path}`, {
      headers: { 'User-Agent': UA, 'Accept-Language': 'fr' },
    });
    if (!resp.ok) throw new Error(`Géocodeur indisponible (${resp.status})`);
    const data = await resp.json();
    if (cache.size > 500) cache.clear();
    cache.set(path, data);
    return data;
  }

  r.get('/search', requireAuth(db), async (req, res) => {
    const q = String(req.query.q || '').trim();
    if (q.length < 3) return res.json({ results: [] });
    try {
      const data = await nominatim(`search?format=json&addressdetails=0&limit=6&countrycodes=fr,be,es,it,gb&q=${encodeURIComponent(q)}`);
      res.json({ results: data.map((d) => ({ address: d.display_name, lat: Number(d.lat), lng: Number(d.lon) })) });
    } catch (e) {
      res.status(502).json({ error: `Recherche d’adresse indisponible (${e.message})` });
    }
  });

  r.get('/reverse', requireAuth(db), async (req, res) => {
    const lat = Number(req.query.lat), lng = Number(req.query.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return res.status(400).json({ error: 'Coordonnées invalides' });
    try {
      const d = await nominatim(`reverse?format=json&lat=${lat}&lon=${lng}`);
      res.json({ address: d.display_name || `${lat.toFixed(5)}, ${lng.toFixed(5)}`, lat, lng });
    } catch (e) {
      res.status(502).json({ error: `Recherche d’adresse indisponible (${e.message})` });
    }
  });

  return r;
};

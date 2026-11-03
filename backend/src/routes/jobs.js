const express = require('express');
const { requireAuth } = require('../auth');
const { quote, validPoint, SIZES, URGENCY, VEHICLES } = require('../pricing');

module.exports = function jobRoutes(db, jobs) {
  const r = express.Router();
  const wrap = (fn) => (req, res, next) => { try { fn(req, res); } catch (e) { next(e); } };

  // Données de référence (véhicules, tailles, urgences) pour construire les formulaires
  r.get('/catalog', (req, res) => {
    res.json({
      sizes: SIZES,
      urgencies: Object.entries(URGENCY).map(([key, u]) => ({ key, ...u })),
      vehicles: Object.entries(VEHICLES).map(([key, v]) => ({ key, ...v })),
    });
  });

  r.post('/quotes', requireAuth(db), wrap((req, res) => {
    const { pickup, dropoff, packageSize = 'S', urgency = 'standard' } = req.body || {};
    const p = { lat: Number(pickup?.lat), lng: Number(pickup?.lng) };
    const d = { lat: Number(dropoff?.lat), lng: Number(dropoff?.lng) };
    if (!validPoint(p) || !validPoint(d)) return res.status(400).json({ error: 'Coordonnées invalides' });
    if (!SIZES.includes(packageSize) || !URGENCY[urgency]) return res.status(400).json({ error: 'Paramètres invalides' });
    res.json(quote({ pickup: p, dropoff: d, packageSize, urgency }));
  }));

  r.post('/jobs', requireAuth(db, 'client', 'admin'), wrap((req, res) => {
    res.status(201).json({ job: jobs.viewFor(jobs.create(req.user, req.body || {}), req.user) });
  }));

  r.get('/jobs', requireAuth(db), (req, res) => {
    const u = req.user;
    const { status } = req.query;
    let list = u.role === 'admin' ? db.jobs.all()
      : u.role === 'courier' ? db.jobs.find((j) => j.courierId === u.id)
      : db.jobs.find((j) => j.clientId === u.id);
    if (status === 'active') list = list.filter((j) => ['pending', ...jobs.ACTIVE].includes(j.status));
    else if (status === 'done') list = list.filter((j) => ['delivered', 'failed', 'cancelled'].includes(j.status));
    else if (status) list = list.filter((j) => j.status === status);
    res.json({ jobs: [...list].sort((a, b) => b.createdAt.localeCompare(a.createdAt)).map((j) => jobs.viewFor(j, u)) });
  });

  r.get('/jobs/:id', requireAuth(db), (req, res) => {
    const j = db.jobs.byId(req.params.id);
    const u = req.user;
    const allowed = j && (u.role === 'admin' || j.clientId === u.id || j.courierId === u.id ||
      (u.role === 'courier' && j.status === 'pending'));
    if (!allowed) return res.status(404).json({ error: 'Course introuvable' });
    res.json({ job: jobs.viewFor(j, u) });
  });

  r.post('/jobs/:id/cancel', requireAuth(db, 'client', 'admin'), wrap((req, res) => {
    res.json({ job: jobs.viewFor(jobs.cancel(req.user, req.params.id, req.body?.reason), req.user) });
  }));

  r.post('/jobs/:id/rate', requireAuth(db, 'client'), wrap((req, res) => {
    res.json({ job: jobs.viewFor(jobs.rate(req.user, req.params.id, req.body || {}), req.user) });
  }));

  return r;
};

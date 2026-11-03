const express = require('express');
const { requireAuth, publicUser } = require('../auth');
const { validPoint, round2 } = require('../pricing');

module.exports = function courierRoutes(db, jobs, io) {
  const r = express.Router();
  const wrap = (fn) => (req, res, next) => { try { fn(req, res); } catch (e) { next(e); } };
  r.use(requireAuth(db, 'courier'));

  r.patch('/status', (req, res) => {
    const online = Boolean(req.body?.online);
    const user = db.users.update(req.user.id, { online });
    // Met à jour l'appartenance au salon "couriers" pour toutes les connexions du coursier
    if (io) {
      const room = io.in(`user:${user.id}`);
      online ? room.socketsJoin('couriers') : room.socketsLeave('couriers');
    }
    res.json({ user: publicUser(user) });
  });

  r.post('/location', (req, res) => {
    const lat = Number(req.body?.lat);
    const lng = Number(req.body?.lng);
    if (!validPoint({ lat, lng })) return res.status(400).json({ error: 'Coordonnées invalides' });
    res.json({ location: jobs.updateCourierLocation(req.user, lat, lng) });
  });

  r.get('/jobs/available', (req, res) => {
    if (!req.user.online) return res.json({ jobs: [] });
    res.json({ jobs: jobs.available(req.user) });
  });

  r.get('/jobs/current', (req, res) => {
    const j = db.jobs.findOne((x) => x.courierId === req.user.id && jobs.ACTIVE.includes(x.status));
    res.json({ job: j ? jobs.viewFor(j, req.user) : null });
  });

  r.post('/jobs/:id/accept', wrap((req, res) => {
    res.json({ job: jobs.viewFor(jobs.accept(req.user, req.params.id), req.user) });
  }));

  r.post('/jobs/:id/status', wrap((req, res) => {
    res.json({ job: jobs.viewFor(jobs.courierUpdate(req.user, req.params.id, req.body || {}), req.user) });
  }));

  r.get('/earnings', (req, res) => {
    const done = db.jobs.find((j) => j.courierId === req.user.id && j.status === 'delivered');
    const startOfDay = new Date(); startOfDay.setHours(0, 0, 0, 0);
    const startOfWeek = new Date(startOfDay); startOfWeek.setDate(startOfWeek.getDate() - ((startOfWeek.getDay() + 6) % 7));
    const sum = (list) => round2(list.reduce((s, j) => s + j.courierEarning, 0));
    const deliveredAt = (j) => new Date(j.updatedAt);
    const today = done.filter((j) => deliveredAt(j) >= startOfDay);
    const week = done.filter((j) => deliveredAt(j) >= startOfWeek);
    res.json({
      today: { count: today.length, amount: sum(today) },
      week: { count: week.length, amount: sum(week) },
      total: { count: done.length, amount: sum(done), distanceKm: round2(done.reduce((s, j) => s + j.distanceKm, 0)) },
      rating: req.user.rating,
      recent: [...done].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt)).slice(0, 20)
        .map((j) => ({ id: j.id, ref: j.ref, amount: j.courierEarning, distanceKm: j.distanceKm, at: j.updatedAt,
          from: j.pickup.address, to: j.dropoff.address })),
    });
  });

  return r;
};

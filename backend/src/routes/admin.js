const express = require('express');
const { requireAuth, publicUser } = require('../auth');
const { round2 } = require('../pricing');

module.exports = function adminRoutes(db, jobs) {
  const r = express.Router();
  r.use(requireAuth(db, 'admin'));

  r.get('/stats', (req, res) => {
    const all = db.jobs.all();
    const by = (s) => all.filter((j) => j.status === s).length;
    const delivered = all.filter((j) => j.status === 'delivered');
    const couriers = db.users.find((u) => u.role === 'courier');
    res.json({
      jobs: {
        total: all.length,
        pending: by('pending'),
        active: all.filter((j) => jobs.ACTIVE.includes(j.status)).length,
        delivered: delivered.length,
        cancelled: by('cancelled'),
        failed: by('failed'),
      },
      revenue: {
        ttc: round2(delivered.reduce((s, j) => s + j.price.ttc, 0)),
        ht: round2(delivered.reduce((s, j) => s + j.price.ht, 0)),
        courierPayouts: round2(delivered.reduce((s, j) => s + j.courierEarning, 0)),
      },
      users: {
        clients: db.users.find((u) => u.role === 'client').length,
        couriers: couriers.length,
        couriersOnline: couriers.filter((c) => c.online).length,
      },
    });
  });

  r.get('/users', (req, res) => {
    const { role } = req.query;
    const list = role ? db.users.find((u) => u.role === role) : db.users.all();
    res.json({ users: list.map(publicUser) });
  });

  r.get('/couriers/live', (req, res) => {
    res.json({
      couriers: db.users.find((u) => u.role === 'courier' && u.online).map((c) => ({
        id: c.id, name: c.name, vehicle: c.vehicle, location: c.location,
        busy: Boolean(db.jobs.findOne((j) => j.courierId === c.id && jobs.ACTIVE.includes(j.status))),
      })),
    });
  });

  return r;
};

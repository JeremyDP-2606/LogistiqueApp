const http = require('http');
const express = require('express');
const cors = require('cors');
const { Server } = require('socket.io');
const { createDb } = require('./db');
const { verifyToken } = require('./auth');
const { createJobService, HttpError } = require('./jobService');

function createApp({ dbFile } = {}) {
  const db = createDb(dbFile);
  const app = express();
  const server = http.createServer(app);
  const origin = (process.env.CORS_ORIGIN || '*').split(',').map((s) => s.trim());
  const corsOpt = { origin: origin.includes('*') ? true : origin };
  const io = new Server(server, { cors: corsOpt });
  const jobs = createJobService(db, io);

  app.use(cors(corsOpt));
  app.use(express.json({ limit: '1mb' }));

  app.get('/api/health', (req, res) => res.json({ ok: true, time: new Date().toISOString() }));
  app.use('/api/auth', require('./routes/auth')(db));
  app.use('/api', require('./routes/jobs')(db, jobs));
  app.use('/api/courier', require('./routes/courier')(db, jobs, io));
  app.use('/api/admin', require('./routes/admin')(db, jobs));
  app.use('/api/geo', require('./routes/geo')(db));

  app.use('/api', (req, res) => res.status(404).json({ error: 'Route inconnue' }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err instanceof HttpError) return res.status(err.status).json({ error: err.message });
    if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'JSON invalide' });
    console.error(err);
    res.status(500).json({ error: 'Erreur serveur' });
  });

  // ---- Temps réel ----
  io.use((socket, next) => {
    try {
      const token = socket.handshake.auth?.token || socket.handshake.query?.token;
      const payload = verifyToken(token);
      const user = db.users.byId(payload.sub);
      if (!user) return next(new Error('unauthorized'));
      socket.data.user = user;
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    const user = socket.data.user;
    socket.join(`user:${user.id}`);
    if (user.role === 'admin') socket.join('admins');
    if (user.role === 'courier' && db.users.byId(user.id)?.online) socket.join('couriers');

    socket.on('job:subscribe', (jobId, ack) => {
      const j = db.jobs.byId(jobId);
      const ok = j && (user.role === 'admin' || j.clientId === user.id || j.courierId === user.id);
      if (ok) socket.join(`job:${jobId}`);
      if (typeof ack === 'function') ack({ ok: Boolean(ok) });
    });
    socket.on('job:unsubscribe', (jobId) => socket.leave(`job:${jobId}`));

    // Les coursiers peuvent aussi pousser leur position via le socket (plus léger que HTTP)
    socket.on('courier:location', ({ lat, lng } = {}) => {
      const me = db.users.byId(user.id);
      if (me?.role !== 'courier' || !Number.isFinite(lat) || !Number.isFinite(lng)) return;
      jobs.updateCourierLocation(me, lat, lng);
    });
  });

  return { app, server, io, db, jobs };
}

module.exports = { createApp };

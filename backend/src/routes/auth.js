const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { signToken, publicUser, requireAuth } = require('../auth');
const { VEHICLES } = require('../pricing');

module.exports = function authRoutes(db) {
  const r = express.Router();

  r.post('/register', (req, res) => {
    const { name, email, password, phone = '', role = 'client', vehicle, company = '' } = req.body || {};
    if (!name || !email || !password) return res.status(400).json({ error: 'Nom, email et mot de passe requis' });
    if (String(password).length < 6) return res.status(400).json({ error: 'Mot de passe : 6 caractères minimum' });
    if (!['client', 'courier'].includes(role)) return res.status(400).json({ error: 'Rôle invalide' });
    if (role === 'courier' && !VEHICLES[vehicle]) return res.status(400).json({ error: 'Véhicule invalide pour un coursier' });
    const normEmail = String(email).trim().toLowerCase();
    if (db.users.findOne((u) => u.email === normEmail)) return res.status(409).json({ error: 'Email déjà utilisé' });

    const user = db.users.insert({
      id: crypto.randomUUID(),
      name: String(name).trim(),
      email: normEmail,
      phone,
      company,
      role,
      passwordHash: bcrypt.hashSync(String(password), 10),
      createdAt: new Date().toISOString(),
      ...(role === 'courier' ? { vehicle, online: false, location: null, rating: 5, ratingsCount: 0 } : {}),
    });
    res.status(201).json({ token: signToken(user), user: publicUser(user) });
  });

  r.post('/login', (req, res) => {
    const { email, password } = req.body || {};
    const user = db.users.findOne((u) => u.email === String(email || '').trim().toLowerCase());
    if (!user || !bcrypt.compareSync(String(password || ''), user.passwordHash)) {
      return res.status(401).json({ error: 'Identifiants incorrects' });
    }
    res.json({ token: signToken(user), user: publicUser(user) });
  });

  r.get('/me', requireAuth(db), (req, res) => res.json({ user: publicUser(req.user) }));

  r.patch('/me', requireAuth(db), (req, res) => {
    const allowed = ['name', 'phone', 'company'];
    const patch = {};
    for (const k of allowed) if (req.body?.[k] !== undefined) patch[k] = String(req.body[k]);
    if (req.user.role === 'courier' && req.body?.vehicle) {
      if (!VEHICLES[req.body.vehicle]) return res.status(400).json({ error: 'Véhicule invalide' });
      patch.vehicle = req.body.vehicle;
    }
    res.json({ user: publicUser(db.users.update(req.user.id, patch)) });
  });

  return r;
};

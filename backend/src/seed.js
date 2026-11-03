// Crée des comptes de démonstration : admin, client et coursiers (mot de passe : demo1234)
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { createDb } = require('./db');

const file = process.env.DB_FILE || path.join(__dirname, '..', 'data', 'db.json');
if (process.argv.includes('--reset') && fs.existsSync(file)) fs.unlinkSync(file);
const db = createDb(file);
const hash = bcrypt.hashSync('demo1234', 10);

const accounts = [
  { name: 'Admin', email: 'admin@demo.fr', role: 'admin' },
  { name: 'Boulangerie Martin', email: 'client@demo.fr', role: 'client', company: 'Boulangerie Martin', phone: '0611223344' },
  { name: 'Léa Coursière', email: 'velo@demo.fr', role: 'courier', vehicle: 'bike', phone: '0622334455', location: { lat: 48.8606, lng: 2.3376 } },
  { name: 'Karim Scooter', email: 'scooter@demo.fr', role: 'courier', vehicle: 'motorbike', phone: '0633445566', location: { lat: 48.8738, lng: 2.295 } },
  { name: 'Sam Voiture', email: 'voiture@demo.fr', role: 'courier', vehicle: 'car', phone: '0644556677', location: { lat: 48.8462, lng: 2.3464 } },
  { name: 'Nora Utilitaire', email: 'van@demo.fr', role: 'courier', vehicle: 'van', phone: '0655667788', location: { lat: 48.8867, lng: 2.3431 } },
];

for (const a of accounts) {
  if (db.users.findOne((u) => u.email === a.email)) continue;
  db.users.insert({
    id: crypto.randomUUID(), phone: '', company: '', ...a, passwordHash: hash, createdAt: new Date().toISOString(),
    ...(a.role === 'courier' ? { online: false, rating: 5, ratingsCount: 0, location: a.location ? { ...a.location, at: new Date().toISOString() } : null } : {}),
  });
  console.log(`+ ${a.role.padEnd(8)} ${a.email}`);
}
db.flush();
console.log('Comptes de démo prêts (mot de passe : demo1234)');

const jwt = require('jsonwebtoken');

const SECRET = () => process.env.JWT_SECRET || 'dev-secret-change-me';

function signToken(user) {
  return jwt.sign({ sub: user.id, role: user.role }, SECRET(), { expiresIn: '30d' });
}

function verifyToken(token) {
  return jwt.verify(token, SECRET());
}

function publicUser(u) {
  if (!u) return null;
  const { passwordHash, ...rest } = u;
  return rest;
}

// Middleware : exige un token valide, et optionnellement un ou plusieurs rôles.
function requireAuth(db, ...roles) {
  return (req, res, next) => {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'Authentification requise' });
    try {
      const payload = verifyToken(token);
      const user = db.users.byId(payload.sub);
      if (!user) return res.status(401).json({ error: 'Utilisateur introuvable' });
      if (roles.length && !roles.includes(user.role)) return res.status(403).json({ error: 'Accès refusé' });
      req.user = user;
      next();
    } catch {
      res.status(401).json({ error: 'Token invalide ou expiré' });
    }
  };
}

module.exports = { signToken, verifyToken, publicUser, requireAuth };

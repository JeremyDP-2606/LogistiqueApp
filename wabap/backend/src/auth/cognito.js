// Vérification des jetons Cognito (signature, expiration, groupe d'utilisateurs, application cliente).
// Les applications envoient le jeton d'identité (ID token) : il porte les groupes (cognito:groups)
// et les attributs personnalisés (custom:clientName) utilisés par les règles d'accès.
const { CognitoJwtVerifier } = require('aws-jwt-verify');

function toIdentity(claims) {
  return {
    sub: claims.sub,
    username: claims['cognito:username'] || claims.username,
    groups: claims['cognito:groups'] || [],
    claims,
  };
}

function createCognitoAuth({ userPoolId, clientIds }) {
  if (!userPoolId) throw new Error('COGNITO_USER_POOL_ID manquant');
  const verifier = CognitoJwtVerifier.create({ userPoolId, tokenUse: null, clientId: clientIds?.length ? clientIds : null });
  return {
    // Préchargement des clés publiques (évite une latence à la première requête)
    async warmUp() { await verifier.hydrate(); },
    async identify(token) {
      if (!token) return null;
      const claims = await verifier.verify(token.replace(/^Bearer\s+/i, ''));
      return toIdentity(claims);
    },
  };
}

// Développement local et démonstrations uniquement (AUTH_MODE=dev) : jeton JWT non signé ou clé de démo
function createDevAuth({ personas = {} } = {}) {
  return {
    async warmUp() {},
    async identify(token) {
      if (!token) return null;
      const t = token.replace(/^Bearer\s+/i, '');
      if (personas[t]) return toIdentity(personas[t]);
      const part = t.split('.')[1];
      if (!part) throw new Error('Jeton invalide');
      const claims = JSON.parse(Buffer.from(part, 'base64url').toString());
      if (claims.exp && claims.exp * 1000 < Date.now()) throw new Error('Jeton expiré');
      return toIdentity(claims);
    },
  };
}

module.exports = { createCognitoAuth, createDevAuth, toIdentity };

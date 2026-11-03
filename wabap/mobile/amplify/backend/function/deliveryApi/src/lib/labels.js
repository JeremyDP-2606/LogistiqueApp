// Identifiants de colis signés (spec §4.2).
// Le code imprimé dans le QR contient l'identifiant du colis, celui du client et une signature
// HMAC : un colis inconnu, d'un autre client ou falsifié est rejeté au scan.
const crypto = require('crypto');

const PREFIX = 'WB1';
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // sans I, L, O, U (lecture humaine)

function shortId(bytes = 6) {
  const buf = crypto.randomBytes(bytes);
  let out = '';
  for (const b of buf) out += ALPHABET[b % 32];
  return out;
}

function sign(secret, parcelId, customerId) {
  return crypto.createHmac('sha256', secret).update(`${parcelId}|${customerId}`).digest('base64url').slice(0, 10);
}

// Ex. WB1.7K2M9QXA.FA.Zx3k9_aQ1b  (préfixe.colis.client.signature)
function encodeCode(secret, parcelId, customerId) {
  return `${PREFIX}.${parcelId}.${customerId}.${sign(secret, parcelId, customerId)}`;
}

// Renvoie { parcelId, customerId } ou une erreur explicite
function decodeCode(secret, code) {
  const parts = String(code || '').trim().split('.');
  if (parts.length !== 4 || parts[0] !== PREFIX) return { error: 'Étiquette non reconnue : seules les étiquettes Wabap sont acceptées' };
  const [, parcelId, customerId, signature] = parts;
  const expected = sign(secret, parcelId, customerId);
  const ok = signature.length === expected.length && crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
  if (!ok) return { error: 'Étiquette invalide (signature incorrecte)' };
  return { parcelId, customerId };
}

module.exports = { shortId, encodeCode, decodeCode, sign };

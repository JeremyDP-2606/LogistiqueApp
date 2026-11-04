// Identifiants de colis signés (spec §4.2).
// Le code imprimé (QR et code-barres) contient l'identifiant du colis, une empreinte courte du
// client et une signature HMAC : un colis inconnu, d'un autre client ou falsifié est rejeté au scan.
// Format (≈ 28 caractères, assez court pour un code-barres sur une étiquette de 10 cm) :
//   WB1.<colis 6>.<client 6>.<signature 10>
const crypto = require('crypto');

const PREFIX = 'WB1';
const ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // sans I, L, O, U (lecture humaine)

function shortId(bytes = 6) {
  const buf = crypto.randomBytes(bytes);
  let out = '';
  for (const b of buf) out += ALPHABET[b % 32];
  return out;
}

// Empreinte stable et courte de l'identifiant client
function customerTag(customerId) {
  const h = crypto.createHash('sha256').update(String(customerId)).digest();
  let out = '';
  for (let i = 0; i < 6; i++) out += ALPHABET[h[i] % 32];
  return out;
}

function sign(secret, parcelId, tag) {
  return crypto.createHmac('sha256', secret).update(`${parcelId}|${tag}`).digest('base64url').slice(0, 10);
}

function encodeCode(secret, parcelId, customerId) {
  const tag = customerTag(customerId);
  return `${PREFIX}.${parcelId}.${tag}.${sign(secret, parcelId, tag)}`;
}

// Renvoie { parcelId, customerTag } ou { error }
function decodeCode(secret, code) {
  const parts = String(code || '').trim().split('.');
  if (parts.length !== 4 || parts[0] !== PREFIX) return { error: 'Étiquette non reconnue : seules les étiquettes Wabap sont acceptées' };
  const [, parcelId, tag, signature] = parts;
  const expected = sign(secret, parcelId, tag);
  const ok = signature.length === expected.length && crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
  if (!ok) return { error: 'Étiquette invalide (signature incorrecte)' };
  return { parcelId, customerTag: tag };
}

module.exports = { shortId, customerTag, encodeCode, decodeCode, sign };

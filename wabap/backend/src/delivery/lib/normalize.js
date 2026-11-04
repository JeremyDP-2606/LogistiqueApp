// Normalisation commune de toute donnée entrante (spec §4.1, étape 3).
// Fonctions pures : aucune dépendance réseau (le géocodage est fait ailleurs).

// Indicatifs des numéros français à 10 chiffres : la métropole est en +33, mais les DOM ont
// leur propre indicatif (un 0696 martiniquais devient +596 696…, pas +33 696…).
const DOM_PREFIXES = [
  ['0596', '596'], ['0696', '596'], ['0697', '596'], // Martinique
  ['0590', '590'], ['0690', '590'], ['0691', '590'], // Guadeloupe, Saint-Martin, Saint-Barthélemy
  ['0594', '594'], ['0694', '594'], // Guyane
  ['0262', '262'], ['0263', '262'], ['0692', '262'], ['0693', '262'], // La Réunion
  ['0269', '262'], ['0639', '262'], // Mayotte
];

function normalizePhone(raw) {
  if (raw === undefined || raw === null) return null;
  let p = String(raw).replace(/[\s.\-()/]/g, '');
  if (!p) return null;
  if (p.startsWith('00')) p = `+${p.slice(2)}`;
  if (/^0\d{9}$/.test(p)) {
    const dom = DOM_PREFIXES.find(([prefix]) => p.startsWith(prefix));
    p = dom ? `+${dom[1]}${p.slice(1)}` : `+33${p.slice(1)}`;
  } else if (/^\d{9}$/.test(p) && /^[67]/.test(p)) {
    p = `+33${p}`; // numéro mobile saisi sans le 0
  }
  return /^\+\d{8,15}$/.test(p) ? p : null;
}

const cleanText = (v) => (v === undefined || v === null ? null : String(v).replace(/\s+/g, ' ').trim() || null);

function normalizeName(v) {
  const s = cleanText(v);
  if (!s) return null;
  // Les noms tout en majuscules (exports de logiciels métiers) sont remis en casse normale
  if (s === s.toUpperCase() && /[A-Z]/.test(s)) {
    return s.toLowerCase().replace(/(^|[\s'-])(\p{L})/gu, (m, sep, ch) => sep + ch.toUpperCase());
  }
  return s;
}

function normalizeEmail(v) {
  const s = cleanText(v);
  if (!s) return null;
  const e = s.toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e) ? e : null;
}

// Découpe d'une adresse française en une ligne : « 12 bis rue Victor Hugo, Bât. B, 97200 Fort-de-France »
function splitAddress(raw) {
  const line = cleanText(raw);
  if (!line) return null;
  const out = { number: null, street: null, complement: null, postalCode: null, city: null, country: 'FR' };
  const cp = line.match(/\b(\d{5})\s+([^,\d][^,]*)$/);
  let rest = line;
  if (cp) {
    out.postalCode = cp[1];
    out.city = cleanText(cp[2]);
    rest = line.slice(0, cp.index).replace(/[,\s]+$/, '');
  }
  const parts = rest.split(',').map((x) => x.trim()).filter(Boolean);
  const first = parts.shift() || '';
  const m = first.match(/^(\d+\s?(?:bis|ter|quater|[a-d])?)\b[\s,]*(.*)$/i);
  if (m) {
    out.number = m[1].replace(/\s+/g, ' ').trim().toLowerCase();
    out.street = cleanText(m[2]);
  } else {
    out.street = cleanText(first);
  }
  if (parts.length) out.complement = parts.join(', ');
  return out;
}

function formatAddress(a) {
  if (!a) return null;
  const head = [a.number, a.street].filter(Boolean).join(' ');
  const tail = [a.postalCode, a.city].filter(Boolean).join(' ');
  return [head, a.complement, tail].filter(Boolean).join(', ');
}

// Applique le mapping d'un connecteur : { champInterne: 'colonne' | ['colonne1', 'colonne2'] }
// Plusieurs colonnes sont concaténées (ex. « numéro » + « rue » + « ville » séparés chez un client).
function applyMapping(record, mapping) {
  const out = {};
  for (const [field, source] of Object.entries(mapping || {})) {
    const cols = Array.isArray(source) ? source : [source];
    const values = cols.map((c) => record[c]).filter((v) => v !== undefined && v !== null && String(v).trim() !== '');
    if (values.length) out[field] = values.map(String).join(' ').trim();
  }
  return out;
}

module.exports = { normalizePhone, normalizeName, normalizeEmail, splitAddress, formatAddress, applyMapping, cleanText };

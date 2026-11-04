// Tarification des courses ponctuelles (spec §11 bis).
// Prix = max(minimum, (prise en charge[taille] + km × prix/km[taille]) × coef[délai]) + suppléments − remise
// La grille est historisée : la grille en vigueur est la plus récente dont la date d'effet est passée,
// et une course déjà payée garde le prix calculé au moment de la commande.
const { round2, fr } = require('./geo');

// Exemples de la spec (« à remplacer »), utilisés tant qu'aucune grille n'est publiée
const DEFAULT_GRID = {
  id: 'defaut',
  effectiveFrom: '2026-01-01T00:00:00.000Z',
  sizes: {
    S: { base: 5, perKm: 0.8, maxWeightKg: 2, maxDims: '30 × 20 × 10 cm' },
    M: { base: 7, perKm: 1.0, maxWeightKg: 10, maxDims: '50 × 40 × 30 cm' },
    L: { base: 10, perKm: 1.3, maxWeightKg: 25, maxDims: '80 × 60 × 50 cm' },
    XL: { base: 15, perKm: 1.8, maxWeightKg: 50, maxDims: '120 × 80 × 80 cm' },
  },
  delayCoefs: { 1: 1.5, 2: 1.2, 3: 1.0 },
  minimum: 10,
  options: { deadline: 5, reinforcedProof: 3, nightPercent: 20, weekendPercent: 15 },
  vatRate: 0.085,
  proofProfileId: null,
};

function parseGrid(g) {
  if (!g) return DEFAULT_GRID;
  const j = (v) => (typeof v === 'string' ? JSON.parse(v) : v);
  return { ...DEFAULT_GRID, ...g, sizes: j(g.sizes) || DEFAULT_GRID.sizes, delayCoefs: j(g.delayCoefs) || DEFAULT_GRID.delayCoefs, options: { ...DEFAULT_GRID.options, ...(j(g.options) || {}) } };
}

// Grille en vigueur à une date (la plus récente déjà entrée en vigueur)
function gridAt(grids, atIso) {
  const valid = grids.filter((g) => g.status !== 'DRAFT' && g.effectiveFrom <= atIso).sort((a, b) => b.effectiveFrom.localeCompare(a.effectiveFrom));
  return parseGrid(valid[0]);
}

class QuoteError extends Error {
  constructor(message, code) { super(message); this.code = code; }
}

/**
 * @param km      distance estimée de l'itinéraire A → B
 * @param input   { size, weightKg, maxDays, options: { deadline, reinforcedProof, night, weekend } }
 * @param promo   { code, percent?, amount? } déjà validé, ou null
 */
function priceCourse(grid, km, input, promo = null) {
  const g = parseGrid(grid);
  const size = g.sizes[input.size];
  if (!size) throw new QuoteError('Taille de colis inconnue', 'INVALID_SIZE');
  if (input.weightKg && size.maxWeightKg && input.weightKg > size.maxWeightKg) {
    const bigger = Object.entries(g.sizes).find(([, s]) => !s.maxWeightKg || input.weightKg <= s.maxWeightKg);
    if (!bigger) throw new QuoteError('Colis hors gabarit : demandez un devis à Wabap', 'MANUAL_QUOTE');
    throw new QuoteError(`Trop lourd pour la taille ${input.size} : choisissez ${bigger[0]}`, 'SIZE_TOO_SMALL');
  }
  const coef = g.delayCoefs[String(input.maxDays)];
  if (!coef) throw new QuoteError('Délai invalide (1, 2 ou 3 jours)', 'INVALID_DELAY');

  const lines = [];
  const pickupFee = size.base;
  const kmFee = round2(km * size.perKm);
  lines.push({ label: `Prise en charge (taille ${input.size})`, amount: pickupFee });
  lines.push({ label: `${fr(km)} km × ${fr(size.perKm)} €`, amount: kmFee });
  let price = (pickupFee + kmFee) * coef;
  if (coef !== 1) lines.push({ label: `Délai ${input.maxDays} jour${input.maxDays > 1 ? 's' : ''} (× ${String(coef).replace('.', ',')})`, amount: round2(price - pickupFee - kmFee) });
  if (price < g.minimum) {
    lines.push({ label: `Minimum par course (${fr(g.minimum)} €)`, amount: round2(g.minimum - price) });
    price = g.minimum;
  }
  const o = input.options || {};
  const base = price;
  if (o.deadline) { price += g.options.deadline; lines.push({ label: 'Supplément heure limite', amount: g.options.deadline }); }
  if (o.reinforcedProof) { price += g.options.reinforcedProof; lines.push({ label: 'Supplément preuve renforcée', amount: g.options.reinforcedProof }); }
  if (o.night) { const a = round2((base * g.options.nightPercent) / 100); price += a; lines.push({ label: `Majoration nuit (+${g.options.nightPercent} %)`, amount: a }); }
  if (o.weekend) { const a = round2((base * g.options.weekendPercent) / 100); price += a; lines.push({ label: `Majoration week-end (+${g.options.weekendPercent} %)`, amount: a }); }
  if (promo) {
    const discount = round2(Math.min(price, promo.amount ?? (price * (promo.percent || 0)) / 100));
    if (discount > 0) { price -= discount; lines.push({ label: `Code promo ${promo.code}`, amount: -discount }); }
  }
  const total = round2(price);
  return {
    gridId: g.id,
    km: round2(km),
    lines,
    total,
    vat: round2(total - total / (1 + g.vatRate)), // prix affichés TTC
    currency: 'EUR',
  };
}

module.exports = { DEFAULT_GRID, parseGrid, gridAt, priceCourse, QuoteError };

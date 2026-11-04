// Rémunération des livreurs (spec §9).
// Kilométrage retenu : celui de l'itinéraire optimisé (estimé), jamais la trace GPS.
// Chaque tronçon est payé au tarif du créneau (jour / nuit) de son heure, et au tarif du type de client
// selon la règle de répartition des tournées mutualisées.
const { round2, fr } = require('./geo');
const { UserError, isFinance } = require('./orders');

const DEFAULT_RATE_GRID = {
  id: 'defaut',
  effectiveFrom: '2026-01-01T00:00:00.000Z',
  rates: { default: { DAY: 0.6, NIGHT: 0.8 } }, // € par km, par type de client et créneau
  nightStart: '21:00',
  nightEnd: '06:00',
  perStop: 0,
  perParcel: 0,
  minimumPerTour: 0,
  weekendPercent: 0,
  heavyParcelKg: 25,
  heavyParcelBonus: 0,
  splitRule: 'POINTS', // POINTS | PARCELS | KM (question ouverte de la spec : réglable)
};

function parseGrid(g) {
  if (!g) return DEFAULT_RATE_GRID;
  const rates = typeof g.rates === 'string' ? JSON.parse(g.rates) : g.rates;
  return { ...DEFAULT_RATE_GRID, ...g, rates: rates || DEFAULT_RATE_GRID.rates };
}

function gridAt(grids, atIso) {
  const valid = grids.filter((g) => g.status !== 'DRAFT' && g.effectiveFrom <= atIso).sort((a, b) => b.effectiveFrom.localeCompare(a.effectiveFrom));
  return parseGrid(valid[0]);
}

const minutes = (hhmm) => { const [h, m] = hhmm.split(':').map(Number); return h * 60 + m; };

function slotAt(iso, grid, tzOffsetMin) {
  const d = new Date(new Date(iso).getTime() + tzOffsetMin * 60000);
  const t = d.getUTCHours() * 60 + d.getUTCMinutes();
  const s = minutes(grid.nightStart), e = minutes(grid.nightEnd);
  const night = s > e ? t >= s || t < e : t >= s && t < e;
  return night ? 'NIGHT' : 'DAY';
}

function isWeekend(dateIso, tzOffsetMin) {
  const d = new Date(new Date(dateIso).getTime() + tzOffsetMin * 60000).getUTCDay();
  return d === 0 || d === 6;
}

/**
 * Calcul pur.
 * @param stops [{ legKm, eta, status, customerTypeId, parcels: [{ weightKg, delivered }] }] dans l'ordre
 * @param grid  grille en vigueur à la date de la tournée
 */
function computeEarning(tour, stops, grid, { tzOffsetMinutes = -240 } = {}) {
  const g = parseGrid(grid);
  const rate = (type, slot) => (g.rates[type] || g.rates.default || DEFAULT_RATE_GRID.rates.default)[slot];
  const lines = [];
  // Kilomètres par créneau, attribués aux types de client
  const bySlot = { DAY: [], NIGHT: [] };
  for (const s of stops) bySlot[slotAt(s.eta, g, tzOffsetMinutes)].push(s);
  let kmAmount = 0;
  let totalKm = 0;
  for (const slot of ['DAY', 'NIGHT']) {
    const list = bySlot[slot];
    const km = list.reduce((a, s) => a + (s.legKm || 0), 0);
    if (!km) continue;
    totalKm += km;
    const shares = new Map();
    for (const s of list) {
      const type = s.customerTypeId || 'default';
      const w = g.splitRule === 'KM' ? s.legKm || 0 : g.splitRule === 'PARCELS' ? s.parcels.length : 1;
      shares.set(type, (shares.get(type) || 0) + w);
    }
    const totalW = [...shares.values()].reduce((a, b) => a + b, 0) || 1;
    for (const [type, w] of shares) {
      const typeKm = round2((km * w) / totalW);
      const amount = round2(typeKm * rate(type, slot));
      kmAmount += amount;
      lines.push({ kind: 'KM', label: `${fr(typeKm)} km ${slot === 'NIGHT' ? 'de nuit' : 'de jour'} · ${type === 'default' ? 'tous clients' : type} × ${fr(rate(type, slot))} €`, km: typeKm, slot, customerTypeId: type, amount });
    }
  }
  let total = kmAmount;
  const doneStops = stops.filter((s) => ['DONE', 'PARTIAL'].includes(s.status)).length;
  if (g.perStop && doneStops) { const a = round2(doneStops * g.perStop); total += a; lines.push({ kind: 'STOP', label: `${doneStops} point(s) × ${fr(g.perStop)} €`, amount: a }); }
  const delivered = stops.flatMap((s) => s.parcels).filter((p) => p.delivered);
  if (g.perParcel && delivered.length) { const a = round2(delivered.length * g.perParcel); total += a; lines.push({ kind: 'PARCEL', label: `${delivered.length} colis × ${fr(g.perParcel)} €`, amount: a }); }
  const heavy = delivered.filter((p) => p.weightKg && p.weightKg >= g.heavyParcelKg).length;
  if (g.heavyParcelBonus && heavy) { const a = round2(heavy * g.heavyParcelBonus); total += a; lines.push({ kind: 'HEAVY', label: `${heavy} colis lourd(s) × ${fr(g.heavyParcelBonus)} €`, amount: a }); }
  if (g.weekendPercent && isWeekend(tour.startTime, tzOffsetMinutes)) {
    const a = round2((kmAmount * g.weekendPercent) / 100); total += a; lines.push({ kind: 'WEEKEND', label: `Majoration week-end (+${g.weekendPercent} %)`, amount: a });
  }
  if (g.minimumPerTour && total < g.minimumPerTour) {
    lines.push({ kind: 'MINIMUM', label: `Minimum par tournée (${fr(g.minimumPerTour)} €)`, amount: round2(g.minimumPerTour - total) });
    total = g.minimumPerTour;
  }
  return { gridId: g.id, km: round2(totalKm), lines, amount: round2(total) };
}

function createEarnings(ctx) {
  const { store } = ctx;
  const tz = ctx.config?.tzOffsetMinutes ?? -240;
  const iso = () => (ctx.now ? ctx.now() : new Date()).toISOString();
  const requireStaff = (identity) => { if (!isFinance(identity)) throw new UserError('Réservé à la comptabilité Wabap'); };

  async function gridFor(tour) {
    return gridAt(await store.query('RateGrid', 'byKind', 'kind', 'COURIER'), tour.startTime);
  }

  async function stopsForPay(stops) {
    const out = [];
    for (const s of stops) {
      const customer = await store.get('Customer', s.customerId);
      const parcels = [];
      for (const id of s.parcelIds) {
        const p = await store.get('Parcel', id);
        if (p && p.labelStatus === 'ACTIVE') parcels.push({ weightKg: p.weightKg, delivered: s.type === 'DELIVERY' && p.status === 'DELIVERED' });
      }
      out.push({ legKm: s.legKm, eta: s.eta, status: s.status, customerTypeId: customer?.customerTypeId || 'default', parcels });
    }
    return out;
  }

  // Estimation affichée au dispatcher et au livreur avant la tournée (spec §6.2)
  async function estimate(tourId) {
    const tour = await store.get('Tour', tourId);
    const stops = (await store.query('Stop', 'byTour', 'tourId', tourId)).sort((a, b) => a.sequence - b.sequence);
    return computeEarning(tour, await stopsForPay(stops.map((s) => ({ ...s, status: 'DONE' }))), await gridFor(tour), { tzOffsetMinutes: tz });
  }

  // À la clôture : gain affiché au livreur, à valider par Wabap
  async function onTourClosed(tour, stops) {
    if (!tour.courierId) return null;
    const fresh = [];
    for (const s of stops) fresh.push(await store.get('Stop', s.id));
    const calc = computeEarning(tour, await stopsForPay(fresh.sort((a, b) => a.sequence - b.sequence)), await gridFor(tour), { tzOffsetMinutes: tz });
    const item = {
      __typename: 'TourEarning',
      id: tour.id,
      tourId: tour.id,
      tourRef: tour.ref,
      courierId: tour.courierId,
      date: tour.date,
      month: tour.date.slice(0, 7),
      ...calc,
      lines: JSON.stringify(calc.lines),
      adjustments: [],
      status: 'TO_VALIDATE',
      createdAt: iso(),
      updatedAt: iso(),
    };
    await store.put('TourEarning', item);
    return item;
  }

  async function adjust(identity, { tourId, amount, reason }) {
    requireStaff(identity);
    if (!reason) throw new UserError('Indiquez le motif de l’ajustement');
    const e = await store.get('TourEarning', tourId);
    if (!e) throw new UserError('Rémunération introuvable');
    if (e.status === 'PAID') throw new UserError('Rémunération déjà payée');
    const adjustments = [...(e.adjustments || []), { amount: round2(amount), reason, by: identity.sub, at: iso() }];
    const total = round2(JSON.parse(e.lines).reduce((s, l) => s + l.amount, 0) + adjustments.reduce((s, a) => s + a.amount, 0));
    if (total < 0) throw new UserError('Le montant ne peut pas devenir négatif');
    return store.update('TourEarning', tourId, { adjustments, amount: total, status: 'TO_VALIDATE', updatedAt: iso() });
  }

  async function validate(identity, { tourId }) {
    requireStaff(identity);
    const tour = await store.get('Tour', tourId);
    const e = await store.update('TourEarning', tourId, { status: 'VALIDATED', validatedBy: identity.sub, validatedAt: iso(), updatedAt: iso() }, { status: 'TO_VALIDATE' });
    if (tour) await store.update('Tour', tourId, { status: 'VALIDATED', updatedAt: iso() });
    return e;
  }

  // Relevé mensuel d'un livreur (spec §9.3)
  async function statement(identity, { courierId, month }) {
    if (!isFinance(identity) && identity.sub !== courierId) throw new UserError('Relevé introuvable');
    const items = (await store.query('TourEarning', 'byCourier', 'courierId', courierId)).filter((e) => e.month === month)
      .sort((a, b) => a.date.localeCompare(b.date));
    const id = `${courierId}-${month}`;
    const saved = await store.get('CourierStatement', id);
    const status = saved?.status === 'PAID' ? 'PAID' : items.length && items.every((e) => ['VALIDATED', 'PAID'].includes(e.status)) ? 'VALIDATED' : 'TO_VALIDATE';
    return {
      id, courierId, month, status,
      paidAt: saved?.paidAt || null,
      tours: items.map((e) => ({ tourId: e.tourId, ref: e.tourRef, date: e.date, km: e.km, amount: e.amount, status: e.status, lines: JSON.parse(e.lines), adjustments: e.adjustments })),
      km: round2(items.reduce((s, e) => s + e.km, 0)),
      total: round2(items.reduce((s, e) => s + e.amount, 0)),
    };
  }

  async function markPaid(identity, { courierId, month }) {
    requireStaff(identity);
    const st = await statement(identity, { courierId, month });
    if (st.status !== 'VALIDATED') throw new UserError('Validez toutes les tournées du mois avant de marquer le relevé payé');
    const at = iso();
    await store.put('CourierStatement', { __typename: 'CourierStatement', id: st.id, courierId, month, total: st.total, status: 'PAID', paidAt: at, paidBy: identity.sub, createdAt: at, updatedAt: at });
    for (const t of st.tours) await store.update('TourEarning', t.tourId, { status: 'PAID', updatedAt: at });
    return { ...st, status: 'PAID', paidAt: at };
  }

  // Export CSV mensuel (séparateur « ; » pour Excel en français)
  async function exportCsv(identity, { month, courierIds }) {
    requireStaff(identity);
    const rows = [['Livreur', 'Mois', 'Tournées', 'Kilomètres', 'Montant (€)', 'Statut', 'Payé le']];
    for (const id of courierIds) {
      const st = await statement(identity, { courierId: id, month });
      if (!st.tours.length) continue;
      const profile = await store.get('CourierProfile', id);
      rows.push([profile?.name || id, month, st.tours.length, String(st.km).replace('.', ','), st.total.toFixed(2).replace('.', ','),
        { TO_VALIDATE: 'À valider', VALIDATED: 'Validé', PAID: 'Payé' }[st.status], st.paidAt ? st.paidAt.slice(0, 10) : '']);
    }
    return rows.map((r) => r.map((c) => (/[;"\n]/.test(String(c)) ? `"${String(c).replace(/"/g, '""')}"` : c)).join(';')).join('\r\n');
  }

  // « Mes gains » : par tournée, par jour, cumul du mois, statut de paiement (spec §7)
  async function myEarnings(identity, { month }) {
    const st = await statement(identity, { courierId: identity.sub, month });
    const byDay = new Map();
    for (const t of st.tours) byDay.set(t.date, round2((byDay.get(t.date) || 0) + t.amount));
    return { ...st, days: [...byDay.entries()].map(([date, amount]) => ({ date, amount })) };
  }

  return { estimate, onTourClosed, adjust, validate, statement, markPaid, exportCsv, myEarnings };
}

module.exports = { createEarnings, computeEarning, gridAt, slotAt, DEFAULT_RATE_GRID };

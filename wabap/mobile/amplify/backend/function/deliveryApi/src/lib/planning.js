// Ordre des points d'une tournée (spec §6.2, §6.2 bis). Fonctions pures.
// Heuristique « plus proche voisin » avec trois règles :
//  - une livraison n'est possible qu'après la collecte de ses colis ;
//  - un point verrouillé par le dispatcher garde sa position ;
//  - on évite un point si y aller d'abord fait manquer l'heure limite stricte d'un autre point.
// Si une heure limite stricte reste impossible à tenir, on alerte au lieu de cacher le retard.
const { roadKm, round2 } = require('./geo');

const DEFAULTS = { speedKmhDay: 30, speedKmhNight: 40, stopMinutes: 4 };

function travelMinutes(a, b, speedKmh) {
  return (roadKm(a, b) / speedKmh) * 60;
}

const ms = (iso) => (iso ? new Date(iso).getTime() : null);

/**
 * @param start   { latitude, longitude }
 * @param stops   [{ id, address:{latitude,longitude}, requires:[stopIds], deadlineAt, windowStart, windowEnd, hard, locked, sequence }]
 * @param startTime ISO
 * @returns { ordered:[stop + {sequence, eta, km}], alerts, totalKm, totalMinutes }
 */
function plan(start, stops, startTime, { slot = 'DAY', ...opts } = {}) {
  const cfg = { ...DEFAULTS, ...opts };
  const speed = slot === 'NIGHT' ? cfg.speedKmhNight : cfg.speedKmhDay;
  const alerts = [];
  const remaining = new Map(stops.map((s) => [s.id, s]));
  const done = new Set();
  const ordered = [];
  let pos = start;
  let t = ms(startTime);
  let totalKm = 0;

  // Une livraison dont la collecte n'est pas dans la tournée est signalée une fois, puis traitée sans précédence
  const ids = new Set(stops.map((s) => s.id));
  const requires = new Map(stops.map((s) => {
    const missing = (s.requires || []).filter((id) => !ids.has(id));
    if (missing.length) alerts.push({ stopId: s.id, code: 'MISSING_PICKUP', message: 'Livraison sans collecte correspondante dans la tournée' });
    return [s.id, (s.requires || []).filter((id) => ids.has(id))];
  }));
  const ready = (s) => requires.get(s.id).every((id) => done.has(id));
  const arrivalAt = (from, time, s) => time + travelMinutes(from, s.address, speed) * 60000;

  while (remaining.size) {
    const position = ordered.length + 1;
    const all = [...remaining.values()];
    const candidates = all.filter(ready);
    const lockedHere = candidates.find((s) => s.locked && s.sequence === position);
    let next = lockedHere;
    if (!next) {
      const free = candidates.filter((s) => !s.locked || s.sequence < position);
      const pool = free.length ? free : candidates;
      pool.sort((a, b) => roadKm(pos, a.address) - roadKm(pos, b.address));
      const hardOthers = all.filter((s) => s.hard && (s.deadlineAt || s.windowEnd));
      next = pool.find((c) => {
        const leave = Math.max(arrivalAt(pos, t, c), ms(c.windowStart) || 0) + cfg.stopMinutes * 60000;
        return hardOthers.every((h) => h.id === c.id || arrivalAt(c.address, leave, h) <= ms(h.deadlineAt || h.windowEnd));
      });
      if (!next) {
        // Aucun choix ne tient toutes les heures limites : on sert d'abord la plus urgente
        next = [...pool].sort((a, b) => (ms(a.deadlineAt || a.windowEnd) ?? Infinity) - (ms(b.deadlineAt || b.windowEnd) ?? Infinity))[0];
      }
    }
    const km = roadKm(pos, next.address);
    let arrival = arrivalAt(pos, t, next);
    if (next.windowStart && next.hard && arrival < ms(next.windowStart)) arrival = ms(next.windowStart); // attente du créneau
    const limit = ms(next.deadlineAt || next.windowEnd);
    if (limit && arrival > limit) {
      alerts.push({
        stopId: next.id,
        code: next.hard ? 'DEADLINE_MISSED' : 'WINDOW_MISSED',
        message: `${next.hard ? 'Heure limite' : 'Créneau souhaité'} dépassé de ${Math.round((arrival - limit) / 60000)} min`,
      });
    }
    ordered.push({ ...next, sequence: position, eta: new Date(arrival).toISOString(), legKm: round2(km) });
    totalKm += km;
    t = arrival + cfg.stopMinutes * 60000;
    pos = next.address;
    remaining.delete(next.id);
    done.add(next.id);
  }
  return { ordered, alerts, totalKm: round2(totalKm), totalMinutes: Math.round((t - ms(startTime)) / 60000) };
}

// Détour d'un ajout en fin de tournée démarrée (spec §7.2)
function appendDetourKm(lastPoint, newStops) {
  let km = 0, pos = lastPoint;
  for (const s of newStops) { km += roadKm(pos, s.address); pos = s.address; }
  return round2(km);
}

module.exports = { plan, appendDetourKm, travelMinutes, DEFAULTS };

import { useState } from 'react';
import { gql, parseJson } from '../lib/amplify';
import { Q, save } from '../lib/queries';
import { ErrorBox, useAction, useLoad } from '../components/ui';
import { dateTime } from '../lib/format';

const G = save('RateGrid', 'id');
const DEFAULT = { rates: { default: { DAY: 0.6, NIGHT: 0.8 } }, nightStart: '21:00', nightEnd: '06:00', perStop: 0, perParcel: 0, minimumPerTour: 0,
  weekendPercent: 0, heavyParcelKg: 25, heavyParcelBonus: 0, splitRule: 'POINTS' };
const SPLIT = { POINTS: 'Au prorata des points', PARCELS: 'Au prorata des colis', KM: 'Km attribuables à chaque client' };

// Grilles de rémunération des livreurs (spec §9.1), historisées
export default function RateGrids() {
  const { data, error, reload } = useLoad(async () => ({
    grids: (await gql(Q.listRateGrids)).listRateGrids.items.filter((g) => g.kind === 'COURIER').sort((a, b) => b.effectiveFrom.localeCompare(a.effectiveFrom)),
    types: (await gql(Q.listCustomerTypes)).listCustomerTypes.items,
  }));
  const [draft, setDraft] = useState(null);
  const [effectiveFrom, setEffectiveFrom] = useState('');
  const a = useAction();
  if (error) return <ErrorBox error={error} />;
  if (!data) return <div className="empty">Chargement…</div>;
  const nowIso = new Date().toISOString();
  const current = data.grids.find((g) => g.status === 'PUBLISHED' && g.effectiveFrom <= nowIso);
  const g = draft || (current ? { ...current, rates: parseJson(current.rates) } : DEFAULT);
  const typeRows = [['default', 'Par défaut (autres types)'], ...data.types.map((t) => [t.id, t.name])];
  const rate = (t, slot) => g.rates[t]?.[slot] ?? '';
  const setRate = (t, slot, v) => setDraft({ ...g, rates: { ...g.rates, [t]: { ...(g.rates[t] || {}), [slot]: v === '' ? undefined : Number(v) } } });
  const setF = (k) => (e) => setDraft({ ...g, [k]: e.target.type === 'number' ? Number(e.target.value) : e.target.value });
  const publish = () => a.run(async () => {
    if (!effectiveFrom) throw new Error('Choisissez la date d’effet');
    const rates = Object.fromEntries(Object.entries(g.rates).filter(([, r]) => r && Number.isFinite(r.DAY) && Number.isFinite(r.NIGHT)));
    await gql(G.create, { input: {
      kind: 'COURIER', status: 'PUBLISHED', effectiveFrom: new Date(`${effectiveFrom}T00:00:00-04:00`).toISOString(), rates: JSON.stringify(rates),
      nightStart: g.nightStart, nightEnd: g.nightEnd, perStop: g.perStop, perParcel: g.perParcel, minimumPerTour: g.minimumPerTour,
      weekendPercent: g.weekendPercent, heavyParcelKg: g.heavyParcelKg, heavyParcelBonus: g.heavyParcelBonus, splitRule: g.splitRule,
    } });
    setDraft(null); setEffectiveFrom(''); reload();
  });
  return (
    <>
      <div className="head"><h1>Grilles de rémunération</h1><span className="spacer" />{draft && <span className="badge warn">Brouillon non publié</span>}</div>
      <p className="muted">Kilométrage retenu : celui de l’itinéraire optimisé. Chaque tronçon est payé au tarif de son créneau. Une tournée est toujours payée selon la grille en vigueur à sa date.</p>
      <ErrorBox error={a.error} />
      <div className="card">
        <h2>{draft ? 'Brouillon' : current ? `En vigueur depuis le ${dateTime(current.effectiveFrom)}` : 'Grille par défaut'}</h2>
        <table><thead><tr><th>Type de client</th><th>Jour (€/km)</th><th>Nuit (€/km)</th></tr></thead>
          <tbody>{typeRows.map(([t, label]) => (
            <tr key={t}><td>{label}</td>{['DAY', 'NIGHT'].map((s) => <td key={s}><input type="number" step="0.05" value={rate(t, s)} onChange={(e) => setRate(t, s, e.target.value)} style={{ width: 100 }} /></td>)}</tr>
          ))}</tbody></table>
        <div className="form" style={{ marginTop: 12 }}>
          <label className="f">Début de la nuit<input type="time" value={g.nightStart} onChange={setF('nightStart')} /></label>
          <label className="f">Fin de la nuit<input type="time" value={g.nightEnd} onChange={setF('nightEnd')} /></label>
          <label className="f">Forfait par point (€)<input type="number" step="0.1" value={g.perStop} onChange={setF('perStop')} /></label>
          <label className="f">Forfait par colis (€)<input type="number" step="0.1" value={g.perParcel} onChange={setF('perParcel')} /></label>
          <label className="f">Minimum par tournée (€)<input type="number" value={g.minimumPerTour} onChange={setF('minimumPerTour')} /></label>
          <label className="f">Majoration week-end (%)<input type="number" value={g.weekendPercent} onChange={setF('weekendPercent')} /></label>
          <label className="f">Colis lourd à partir de (kg)<input type="number" value={g.heavyParcelKg} onChange={setF('heavyParcelKg')} /></label>
          <label className="f">Bonus colis lourd (€)<input type="number" step="0.5" value={g.heavyParcelBonus} onChange={setF('heavyParcelBonus')} /></label>
          <label className="f">Répartition en tournée mutualisée<select value={g.splitRule} onChange={setF('splitRule')}>{Object.entries(SPLIT).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select></label>
        </div>
        {draft && <div className="row" style={{ marginTop: 14 }}>
          <label className="f">En vigueur à partir du<input type="date" value={effectiveFrom} onChange={(e) => setEffectiveFrom(e.target.value)} /></label>
          <button className="btn" disabled={a.busy} onClick={publish}>Publier</button><button className="btn ghost" onClick={() => setDraft(null)}>Abandonner</button></div>}
      </div>
      {data.grids.length > 0 && <div className="card"><h2>Historique</h2><table><tbody>{data.grids.map((x) => (
        <tr key={x.id}><td>À partir du {dateTime(x.effectiveFrom)}</td><td>{SPLIT[x.splitRule]}</td><td>{x === current ? <span className="badge ok">En vigueur</span> : x.effectiveFrom > nowIso ? <span className="badge info">À venir</span> : <span className="badge muted">Archivée</span>}</td></tr>
      ))}</tbody></table></div>}
    </>
  );
}

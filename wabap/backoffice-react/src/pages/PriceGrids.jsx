import { useState } from 'react';
import { gql, parseJson } from '../lib/amplify';
import { Q, save } from '../lib/queries';
import { ErrorBox, useAction, useLoad } from '../components/ui';
import { DEFAULT_GRID, priceCourse } from '../lib/pricing';
import { dateTime, eur } from '../lib/format';

const G = save('PriceGrid', 'id kind effectiveFrom status');
const SIZES = ['S', 'M', 'L', 'XL'];

const fromRecord = (g) => ({
  sizes: parseJson(g.sizes), delayCoefs: parseJson(g.delayCoefs), minimum: g.minimum,
  options: { ...DEFAULT_GRID.options, ...(parseJson(g.options) || {}) }, vatRate: g.vatRate, proofProfileId: g.proofProfileId || '',
});

// Tarifs des courses ponctuelles (spec §11 bis) : grille historisée, simulateur avant publication
export default function PriceGrids() {
  const { data, error, reload } = useLoad(async () => {
    const grids = (await gql(Q.listPriceGrids)).listPriceGrids.items.filter((g) => g.kind === 'COURSE').sort((a, b) => b.effectiveFrom.localeCompare(a.effectiveFrom));
    const profiles = (await gql(Q.listProofProfiles)).listProofProfiles.items;
    return { grids, profiles };
  });
  const [draft, setDraft] = useState(null);
  const [effectiveFrom, setEffectiveFrom] = useState('');
  const [sim, setSim] = useState({ km: 8, size: 'M', maxDays: 2, deadline: false, night: false, weekend: false });
  const a = useAction();
  if (error) return <ErrorBox error={error} />;
  if (!data) return <div className="empty">Chargement…</div>;
  const nowIso = new Date().toISOString();
  const current = data.grids.find((g) => g.status === 'PUBLISHED' && g.effectiveFrom <= nowIso);
  const g = draft || (current ? fromRecord(current) : { ...DEFAULT_GRID });
  const setSize = (s, k, v) => setDraft({ ...g, sizes: { ...g.sizes, [s]: { ...g.sizes[s], [k]: Number(v) } } });
  let simResult = null, simError = null;
  try { simResult = priceCourse(g, Number(sim.km), { size: sim.size, maxDays: Number(sim.maxDays), options: sim }); } catch (e) { simError = e.message; }

  const publish = () => a.run(async () => {
    if (!effectiveFrom) throw new Error('Choisissez la date d’effet');
    await gql(G.create.replace('{ id kind effectiveFrom status }', '{ id }'), { input: {
      kind: 'COURSE', status: 'PUBLISHED', effectiveFrom: new Date(`${effectiveFrom}T00:00:00-04:00`).toISOString(),
      sizes: JSON.stringify(g.sizes), delayCoefs: JSON.stringify(g.delayCoefs), minimum: Number(g.minimum),
      options: JSON.stringify(g.options), vatRate: Number(g.vatRate), proofProfileId: g.proofProfileId || null,
    } });
    setDraft(null); setEffectiveFrom(''); reload();
  });

  return (
    <>
      <div className="head"><h1>Tarifs des courses</h1><span className="spacer" />
        {draft && <span className="badge warn">Brouillon non publié</span>}</div>
      <p className="muted">Prix = max(minimum ; (prise en charge + km × prix au km) × coefficient de délai) + suppléments. Grille unique pour toutes les courses ponctuelles ; une course déjà payée garde son prix.</p>
      <ErrorBox error={a.error} />
      <div className="grid2">
        <div className="card">
          <h2>Grille {draft ? '(brouillon)' : current ? `en vigueur depuis le ${dateTime(current.effectiveFrom)}` : 'par défaut (exemple de la spec)'}</h2>
          <table><thead><tr><th>Taille</th><th>Prise en charge (€)</th><th>Prix au km (€)</th><th>Poids max (kg)</th></tr></thead>
            <tbody>{SIZES.map((s) => (
              <tr key={s}><td><b>{s}</b></td>
                <td><input type="number" step="0.5" value={g.sizes[s].base} onChange={(e) => setSize(s, 'base', e.target.value)} style={{ width: 90 }} /></td>
                <td><input type="number" step="0.05" value={g.sizes[s].perKm} onChange={(e) => setSize(s, 'perKm', e.target.value)} style={{ width: 90 }} /></td>
                <td><input type="number" value={g.sizes[s].maxWeightKg} onChange={(e) => setSize(s, 'maxWeightKg', e.target.value)} style={{ width: 90 }} /></td></tr>
            ))}</tbody></table>
          <div className="form" style={{ marginTop: 12 }}>
            {[1, 2, 3].map((d) => <label key={d} className="f">Coefficient {d} jour{d > 1 ? 's' : ''}<input type="number" step="0.05" value={g.delayCoefs[d]} onChange={(e) => setDraft({ ...g, delayCoefs: { ...g.delayCoefs, [d]: Number(e.target.value) } })} /></label>)}
            <label className="f">Minimum (€)<input type="number" value={g.minimum} onChange={(e) => setDraft({ ...g, minimum: Number(e.target.value) })} /></label>
            <label className="f">Supplément heure limite (€)<input type="number" value={g.options.deadline} onChange={(e) => setDraft({ ...g, options: { ...g.options, deadline: Number(e.target.value) } })} /></label>
            <label className="f">Supplément preuve renforcée (€)<input type="number" value={g.options.reinforcedProof} onChange={(e) => setDraft({ ...g, options: { ...g.options, reinforcedProof: Number(e.target.value) } })} /></label>
            <label className="f">Majoration nuit (%)<input type="number" value={g.options.nightPercent} onChange={(e) => setDraft({ ...g, options: { ...g.options, nightPercent: Number(e.target.value) } })} /></label>
            <label className="f">Majoration week-end (%)<input type="number" value={g.options.weekendPercent} onChange={(e) => setDraft({ ...g, options: { ...g.options, weekendPercent: Number(e.target.value) } })} /></label>
            <label className="f">TVA incluse<input type="number" step="0.005" value={g.vatRate} onChange={(e) => setDraft({ ...g, vatRate: Number(e.target.value) })} /></label>
            <label className="f">Profil de preuve des courses<select value={g.proofProfileId || ''} onChange={(e) => setDraft({ ...g, proofProfileId: e.target.value })}>
              <option value="">Aucun</option>{data.profiles.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
          </div>
          {draft && (
            <div className="row" style={{ marginTop: 14 }}>
              <label className="f">En vigueur à partir du<input type="date" value={effectiveFrom} onChange={(e) => setEffectiveFrom(e.target.value)} /></label>
              <button className="btn" disabled={a.busy} onClick={publish}>Publier la grille</button>
              <button className="btn ghost" onClick={() => setDraft(null)}>Abandonner</button>
            </div>
          )}
        </div>
        <div className="card">
          <h2>Simulateur</h2>
          <div className="form">
            <label className="f">Distance (km)<input type="number" step="0.5" value={sim.km} onChange={(e) => setSim({ ...sim, km: e.target.value })} /></label>
            <label className="f">Taille<select value={sim.size} onChange={(e) => setSim({ ...sim, size: e.target.value })}>{SIZES.map((s) => <option key={s}>{s}</option>)}</select></label>
            <label className="f">Délai<select value={sim.maxDays} onChange={(e) => setSim({ ...sim, maxDays: e.target.value })}>{[1, 2, 3].map((d) => <option key={d} value={d}>{d} jour{d > 1 ? 's' : ''}</option>)}</select></label>
          </div>
          <div className="row small" style={{ marginTop: 8 }}>
            {[['deadline', 'Heure limite'], ['night', 'Nuit'], ['weekend', 'Week-end']].map(([k, l]) => (
              <label key={k} className="row"><input type="checkbox" checked={sim[k]} onChange={(e) => setSim({ ...sim, [k]: e.target.checked })} /> {l}</label>))}
          </div>
          {simError ? <div className="error" style={{ marginTop: 12 }}>{simError}</div> : (
            <table style={{ marginTop: 12 }}><tbody>
              {simResult.lines.map((l, i) => <tr key={i}><td>{l.label}</td><td style={{ textAlign: 'right' }}>{eur(l.amount)}</td></tr>)}
              <tr><td><b>Prix client TTC</b></td><td style={{ textAlign: 'right' }}><b>{eur(simResult.total)}</b></td></tr>
              <tr><td className="muted small">dont TVA</td><td className="muted small" style={{ textAlign: 'right' }}>{eur(simResult.vat)}</td></tr>
            </tbody></table>
          )}
        </div>
      </div>
      <div className="card">
        <h2>Historique des grilles</h2>
        {data.grids.length === 0 ? <div className="empty">Aucune grille publiée : la grille d’exemple s’applique</div> : (
          <table><tbody>{data.grids.map((x) => (
            <tr key={x.id}><td>En vigueur à partir du {dateTime(x.effectiveFrom)}</td><td>Minimum {eur(x.minimum)}</td>
              <td>{x === current ? <span className="badge ok">En vigueur</span> : x.effectiveFrom > nowIso ? <span className="badge info">À venir</span> : <span className="badge muted">Archivée</span>}</td>
              <td><button className="btn ghost small" onClick={() => setDraft(fromRecord(x))}>Partir de cette grille</button></td></tr>
          ))}</tbody></table>
        )}
      </div>
    </>
  );
}

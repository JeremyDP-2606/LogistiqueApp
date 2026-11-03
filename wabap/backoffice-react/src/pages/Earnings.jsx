import { useState } from 'react';
import { gql, parseJson } from '../lib/amplify';
import { M, Q } from '../lib/queries';
import { Badge, ErrorBox, Modal, download, useAction, useLoad } from '../components/ui';
import { EARNING_STATUS, date, eur, num, today } from '../lib/format';

// Back-office financier (spec §9.3) : validation des gains par tournée, relevés mensuels, export CSV
export default function Earnings() {
  const [month, setMonth] = useState(today().slice(0, 7));
  const { data, error, reload } = useLoad(async () => {
    const pending = (await gql(Q.earningsToValidate)).listTourEarnings.items.sort((a, b) => a.date.localeCompare(b.date));
    const couriers = (await gql(Q.listCourierProfiles)).listCourierProfiles.items;
    const statements = await Promise.all(couriers.map(async (c) => ({ courier: c, st: parseJson((await gql(Q.courierStatement, { courierId: c.id, month })).courierStatement) })));
    return { pending, couriers, statements: statements.filter((s) => s.st.tours.length) };
  }, [month]);
  const [open, setOpen] = useState(null);
  const [adj, setAdj] = useState({ amount: '', reason: '' });
  const a = useAction();
  if (error) return <ErrorBox error={error} />;
  if (!data) return <div className="empty">Chargement…</div>;
  const name = (id) => data.couriers.find((c) => c.id === id)?.name || id.slice(0, 8);

  const validate = (tourId) => a.run(async () => { await gql(M.validateEarning, { tourId }); setOpen(null); reload(); });
  const adjust = () => a.run(async () => { await gql(M.adjustEarning, { tourId: open.tourId, amount: Number(adj.amount), reason: adj.reason }); setAdj({ amount: '', reason: '' }); setOpen(null); reload(); });
  const pay = (courierId) => a.run(async () => { await gql(M.markStatementPaid, { courierId, month }); reload(); });
  const exportCsv = () => a.run(async () => {
    const csv = (await gql(Q.exportStatementsCsv, { month, courierIds: data.couriers.map((c) => c.id) })).exportStatementsCsv;
    download(`releves-livreurs-${month}.csv`, csv);
  });

  return (
    <>
      <div className="head"><h1>Rémunération des livreurs</h1><span className="spacer" />
        <input type="month" value={month} onChange={(e) => setMonth(e.target.value)} />
        <button className="btn ghost" onClick={exportCsv} disabled={a.busy}>Exporter le mois (CSV)</button></div>
      <ErrorBox error={a.error} />
      <div className="card table-wrap">
        <h2>Tournées à valider ({data.pending.length})</h2>
        {data.pending.length === 0 ? <div className="empty">Tout est validé</div> : (
          <table><thead><tr><th>Tournée</th><th>Date</th><th>Livreur</th><th>Km</th><th>Montant</th><th /></tr></thead>
            <tbody>{data.pending.map((e) => (
              <tr key={e.id}><td><b>{e.tourRef}</b></td><td>{date(e.date)}</td><td>{name(e.courierId)}</td><td>{num(e.km)}</td><td>{eur(e.amount)}</td>
                <td className="row"><button className="btn ghost small" onClick={() => setOpen(e)}>Détail</button><button className="btn small" onClick={() => validate(e.tourId)} disabled={a.busy}>Valider</button></td></tr>
            ))}</tbody></table>
        )}
      </div>
      <div className="card table-wrap">
        <h2>Relevés de {new Date(`${month}-15`).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })}</h2>
        {data.statements.length === 0 ? <div className="empty">Aucune tournée ce mois-ci</div> : (
          <table><thead><tr><th>Livreur</th><th>Tournées</th><th>Km</th><th>Total</th><th>Statut</th><th /></tr></thead>
            <tbody>{data.statements.map(({ courier, st }) => (
              <tr key={courier.id}><td>{courier.name || courier.id}{courier.siret && <div className="small muted">SIRET {courier.siret}</div>}</td>
                <td>{st.tours.length}</td><td>{num(st.km)}</td><td><b>{eur(st.total)}</b></td><td><Badge map={EARNING_STATUS} value={st.status} /></td>
                <td>{st.status === 'VALIDATED' && <button className="btn small" onClick={() => pay(courier.id)} disabled={a.busy}>Marquer payé</button>}</td></tr>
            ))}</tbody></table>
        )}
      </div>
      {open && (
        <Modal title={`${open.tourRef} · ${name(open.courierId)}`} onClose={() => setOpen(null)} actions={<>
          <button className="btn ghost" onClick={() => setOpen(null)}>Fermer</button>
          <button className="btn" onClick={() => validate(open.tourId)} disabled={a.busy}>Valider {eur(open.amount)}</button></>}>
          <table><tbody>
            {parseJson(open.lines).map((l, i) => <tr key={i}><td>{l.label}</td><td style={{ textAlign: 'right' }}>{eur(l.amount)}</td></tr>)}
            {(open.adjustments || []).map((x, i) => <tr key={`a${i}`}><td>Ajustement : {x.reason}</td><td style={{ textAlign: 'right' }}>{eur(x.amount)}</td></tr>)}
            <tr><td><b>Total</b></td><td style={{ textAlign: 'right' }}><b>{eur(open.amount)}</b></td></tr>
          </tbody></table>
          <h3 style={{ marginTop: 14 }}>Ajustement manuel</h3>
          <div className="form"><label className="f">Montant (€, négatif pour retirer)<input type="number" step="0.5" value={adj.amount} onChange={(e) => setAdj({ ...adj, amount: e.target.value })} /></label>
            <label className="f">Motif<input value={adj.reason} onChange={(e) => setAdj({ ...adj, reason: e.target.value })} /></label></div>
          <button className="btn ghost" style={{ marginTop: 8 }} disabled={!adj.amount || !adj.reason || a.busy} onClick={adjust}>Ajouter l’ajustement</button>
        </Modal>
      )}
    </>
  );
}

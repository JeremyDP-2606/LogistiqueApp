import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { gql, parseJson } from '../lib/api';
import { M, Q } from '../lib/queries';
import { Badge, ErrorBox, Modal, useAction, useLoad } from '../components/ui';
import { STOP_STATUS, TOUR_STATUS, date, dateTime, eur, num, time } from '../lib/format';

const OPEN = ['DRAFT', 'PLANNED', 'ASSIGNED', 'ACCEPTED'];

export default function TourDetail() {
  const { id } = useParams();
  const { data, error, reload } = useLoad(async () => {
    const tour = (await gql(Q.getTour, { id })).getTour;
    const [ready, couriers, customers, estimate] = await Promise.all([
      gql(Q.ordersByStatus, { status: 'CREATED' }), gql(Q.listCourierProfiles), gql(Q.listCustomers),
      gql(Q.tourEarningEstimate, { tourId: id }).catch(() => null),
    ]);
    return {
      tour,
      stops: tour.stops.items.sort((a, b) => a.sequence - b.sequence),
      ready: ready.ordersByStatus.items,
      couriers: couriers.listCourierProfiles.items,
      customers: customers.listCustomers.items,
      estimate: estimate ? parseJson(estimate.tourEarningEstimate) : null,
    };
  }, [id]);
  const [picked, setPicked] = useState([]);
  const [modal, setModal] = useState(null);
  const [labelOpts, setLabelOpts] = useState({ customerId: '', extraCount: 0 });
  const [reason, setReason] = useState('');
  const a = useAction();

  if (error) return <ErrorBox error={error} />;
  if (!data) return <div className="empty">Chargement…</div>;
  const { tour, stops } = data;
  const open = OPEN.includes(tour.status);
  const started = tour.status === 'IN_PROGRESS';
  const customerName = (cid) => data.customers.find((c) => c.id === cid)?.name || cid;
  const alertFor = (stopId) => (tour.alerts || []).filter((x) => x.stopId === stopId);
  const candidates = data.ready.filter((o) => !tour.dedicatedCustomerId || o.customerId === tour.dedicatedCustomerId);

  const add = () => a.run(async () => { await gql(M.addOrdersToTour, { tourId: id, orderIds: picked }); setPicked([]); reload(); });
  const optimize = () => a.run(async () => { await gql(M.optimizeTour, { tourId: id }); reload(); });
  const lock = (s) => a.run(async () => { await gql(M.lockStop, { stopId: s.id, locked: !s.locked }); reload(); });
  const assign = (courierId) => a.run(async () => { await gql(M.assignTour, { tourId: id, courierId }); reload(); });
  const remove = (orderId) => a.run(async () => { await gql(M.removeOrderFromTour, { tourId: id, orderId, reason: reason || undefined }); setModal(null); reload(); });
  const labels = () => a.run(async () => {
    const r = parseJson((await gql(M.generateLabels, { tourId: id, customerId: labelOpts.customerId || undefined, extraCount: Number(labelOpts.extraCount) || undefined })).generateLabels);
    setModal(null); window.open(r.url, '_blank'); reload();
  });
  const close = () => a.run(async () => { await gql(M.closeTour, { tourId: id, reason: reason || undefined }); setModal(null); reload(); });

  return (
    <>
      <div className="head">
        <Link to="/tournees" className="muted">← Tournées</Link>
        <h1>{tour.ref}</h1><Badge map={TOUR_STATUS} value={tour.status} />
        <span className="muted">{date(tour.date)} · départ {time(tour.startTime)} · {tour.slot === 'NIGHT' ? 'nuit' : 'jour'}{tour.dedicatedCustomerId ? ` · dédiée à ${customerName(tour.dedicatedCustomerId)}` : ' · mutualisée'}</span>
        <span className="spacer" />
        {open && <button className="btn ghost" onClick={optimize} disabled={a.busy || !stops.length}>Recalculer l’ordre</button>}
        <button className="btn ghost" onClick={() => setModal('labels')}>Étiquettes</button>
        {started && <button className="btn danger" onClick={() => setModal('close')}>Clôturer</button>}
      </div>
      <ErrorBox error={a.error} />
      {(tour.alerts || []).some((x) => x.code === 'DEADLINE_MISSED') && (
        <div className="error">Heure limite impossible à tenir : retirez une demande, changez l’heure de départ ou verrouillez un autre ordre. Le livreur ne peut pas démarrer cette tournée.</div>
      )}
      <div className="stats">
        <div className="stat"><div className="l">Points</div><div className="v">{stops.length}</div></div>
        <div className="stat"><div className="l">Km estimés</div><div className="v">{num(tour.estimatedKm)}</div></div>
        <div className="stat"><div className="l">Durée estimée</div><div className="v">{Math.floor((tour.estimatedMinutes || 0) / 60)} h {String((tour.estimatedMinutes || 0) % 60).padStart(2, '0')}</div></div>
        <div className="stat"><div className="l">Rémunération estimée</div><div className="v">{data.estimate ? eur(data.estimate.amount) : '—'}</div></div>
      </div>
      <div className="card">
        <div className="row"><h2 style={{ margin: 0 }}>Livreur</h2><span style={{ flex: 1 }} />
          <select value={tour.courierId || ''} disabled={!open || a.busy} onChange={(e) => e.target.value && assign(e.target.value)}>
            <option value="">Non attribuée</option>{data.couriers.map((c) => <option key={c.id} value={c.id}>{c.name || c.id}</option>)}</select></div>
      </div>
      <div className="card table-wrap">
        <h2>Points ({stops.length})</h2>
        {stops.length === 0 ? <div className="empty">Ajoutez des demandes prêtes à planifier ci-dessous.</div> : (
          <table>
            <thead><tr><th>#</th><th>Type</th><th>Client</th><th>Adresse</th><th>Colis</th><th>Arrivée estimée</th><th>Heure limite</th><th>Statut</th><th /></tr></thead>
            <tbody>{stops.map((s) => (
              <tr key={s.id}>
                <td><b>{s.sequence}</b>{s.locked && <div className="small" title="Position verrouillée">🔒</div>}</td>
                <td>{s.type === 'PICKUP' ? <span className="badge info">Collecte</span> : <span className="badge ok">Livraison</span>}</td>
                <td>{customerName(s.customerId)}</td>
                <td>{s.contact?.name && <b>{s.contact.name}<br /></b>}<span className="small">{s.address.formatted}</span>
                  {alertFor(s.id).map((x, i) => <div key={i} className="small" style={{ color: 'var(--err)' }}>{x.message}</div>)}
                  {s.distanceAlert && <div className="small" style={{ color: 'var(--err)' }}>Validé à {num(s.distanceMeters, 0)} m de l’adresse</div>}
                  {s.failureReason && <div className="small" style={{ color: 'var(--err)' }}>{s.failureReason}</div>}</td>
                <td>{s.parcelIds.length}</td>
                <td>{time(s.eta)}<div className="small muted">+{num(s.legKm)} km</div></td>
                <td>{s.deadlineAt ? `${dateTime(s.deadlineAt)}${s.hard ? ' (stricte)' : ''}` : '—'}</td>
                <td><Badge map={STOP_STATUS} value={s.status} /></td>
                <td className="row">
                  {open && <button className="btn ghost small" onClick={() => lock(s)}>{s.locked ? 'Déverrouiller' : 'Verrouiller'}</button>}
                  {(open || started) && s.status === 'TODO' && s.type === 'DELIVERY' && s.orderIds.map((oid) => (
                    <button key={oid} className="btn ghost small" onClick={() => setModal({ remove: oid })}>Retirer</button>))}
                </td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
      {(open || started) && (
        <div className="card table-wrap">
          <div className="row"><h2 style={{ margin: 0 }}>Demandes prêtes à planifier</h2><span style={{ flex: 1 }} />
            <button className="btn" disabled={!picked.length || a.busy} onClick={add}>Insérer {picked.length || ''} demande(s)</button></div>
          {started && <p className="small muted">Tournée démarrée : les demandes sont ajoutées en fin de tournée, sous le seuil de détour, et le livreur est prévenu.</p>}
          {candidates.length === 0 ? <div className="empty">Aucune demande prête{tour.dedicatedCustomerId ? ' pour ce client' : ''}</div> : (
            <table><thead><tr><th /><th>Demande</th><th>Client</th><th>Livraison</th><th>Limite</th></tr></thead>
              <tbody>{candidates.map((o) => (
                <tr key={o.id}><td><input type="checkbox" checked={picked.includes(o.id)} onChange={(e) => setPicked(e.target.checked ? [...picked, o.id] : picked.filter((x) => x !== o.id))} /></td>
                  <td><Link to={`/demandes/${o.id}`}>{o.ref}</Link></td><td>{o.customerName || o.customerId}</td>
                  <td className="small">{o.delivery.address?.formatted}</td><td>{o.deadlineAt ? dateTime(o.deadlineAt) : '—'}</td></tr>
              ))}</tbody></table>
          )}
        </div>
      )}
      {(tour.notices || []).length > 0 && <div className="card"><h2>Journal</h2><ul className="timeline">{tour.notices.map((n, i) => <li key={i}>{dateTime(n.at)} · {n.message}</li>)}</ul></div>}
      {(tour.incidents || []).length > 0 && <div className="card"><h2>Incidents</h2><ul className="timeline">{tour.incidents.map((n, i) => <li key={i}><b>{n.motive}</b> · {customerName(n.customerId)} · colis {n.parcelId}</li>)}</ul></div>}
      {data.estimate && <div className="card"><h2>Rémunération estimée</h2><table><tbody>{data.estimate.lines.map((l, i) => <tr key={i}><td>{l.label}</td><td style={{ textAlign: 'right' }}>{eur(l.amount)}</td></tr>)}</tbody></table></div>}

      {modal === 'labels' && (
        <Modal title="Étiquettes de la tournée" onClose={() => setModal(null)} actions={<>
          <button className="btn ghost" onClick={() => setModal(null)}>Annuler</button>
          <button className="btn" disabled={a.busy || (Number(labelOpts.extraCount) > 0 && !labelOpts.customerId)} onClick={labels}>Générer le PDF</button></>}>
          <div className="form">
            <label className="f">Client<select value={labelOpts.customerId} onChange={(e) => setLabelOpts({ ...labelOpts, customerId: e.target.value })}>
              <option value="">Tous les clients</option>{tour.customerIds.map((c) => <option key={c} value={c}>{customerName(c)}</option>)}</select></label>
            <label className="f">Étiquettes en réserve en plus<input type="number" min="0" value={labelOpts.extraCount} onChange={(e) => setLabelOpts({ ...labelOpts, extraCount: e.target.value })} /></label>
          </div>
          <p className="small muted">Une étiquette en réserve devient un colis au premier scan de collecte ; jamais scannée, elle est abandonnée à la clôture sans alerte.</p>
        </Modal>
      )}
      {modal === 'close' && (
        <Modal title="Clôturer la tournée" onClose={() => setModal(null)} actions={<>
          <button className="btn ghost" onClick={() => setModal(null)}>Annuler</button>
          <button className="btn danger" disabled={a.busy} onClick={close}>Clôturer</button></>}>
          <p>Les points non faits passeront en échec, les étiquettes en réserve non utilisées seront abandonnées, et les colis manquants des clients en mode strict deviendront des incidents.</p>
          <label className="f">Motif (obligatoire s’il reste des points)<input value={reason} onChange={(e) => setReason(e.target.value)} /></label>
        </Modal>
      )}
      {modal?.remove && (
        <Modal title="Retirer la demande de la tournée" onClose={() => setModal(null)} actions={<>
          <button className="btn ghost" onClick={() => setModal(null)}>Annuler</button>
          <button className="btn danger" disabled={a.busy} onClick={() => remove(modal.remove)}>Retirer</button></>}>
          {started && <p>Tournée démarrée : le motif est obligatoire et le livreur sera prévenu.</p>}
          <label className="f">Motif<input value={reason} onChange={(e) => setReason(e.target.value)} /></label>
        </Modal>
      )}
    </>
  );
}

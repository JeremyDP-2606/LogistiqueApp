import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { gql, parseJson } from '../lib/amplify';
import { M, Q } from '../lib/queries';
import { useAuth, ROLES } from '../lib/auth';
import { Badge, ErrorBox, Modal, useAction, useLoad } from '../components/ui';
import { ORDER_STATUS, PARCEL_STATUS, EVENT_LABEL, dateTime, eur, num } from '../lib/format';

function Point({ title, p }) {
  return (
    <div>
      <h3>{title}</h3>
      <div><b>{p.contact?.name || '—'}</b> {p.contact?.phone && <span className="muted">· {p.contact.phone}</span>}</div>
      <div>{p.address?.formatted || <span style={{ color: 'var(--err)' }}>Adresse manquante</span>}</div>
      {p.address && !Number.isFinite(p.address.latitude) && <div className="small" style={{ color: 'var(--err)' }}>Non géocodée</div>}
      {p.instructions && <div className="small muted">{p.instructions}</div>}
    </div>
  );
}

// Historique complet d'un colis (spec §4.4), avec preuves, commentaires et écart de position
function ParcelHistory({ parcel }) {
  const { data, error, loading } = useLoad(async () => parseJson((await gql(Q.parcelHistory, { parcelId: parcel.id })).parcelHistory), [parcel.id]);
  if (loading) return <div className="small muted">Chargement…</div>;
  if (error) return <ErrorBox error={error} />;
  return (
    <ul className="timeline">
      {data.map((e) => {
        const proofs = e.proofs ? parseJson(e.proofs) : null;
        return (
          <li key={e.id}>
            <b>{EVENT_LABEL[e.type] || e.type}</b> · <span className="muted">{dateTime(e.at)}</span>
            {e.method && <span className="small muted"> · {e.method === 'SCAN' ? 'scan' : 'saisie manuelle'}</span>}
            {e.courierId && <span className="small muted"> · livreur {e.courierId.slice(0, 8)}</span>}
            {e.deviceId && <span className="small muted"> · appareil {e.deviceId}</span>}
            {e.comment && <div className="small">Visible client : {e.comment}</div>}
            {e.internalComment && <div className="small muted">Interne : {e.internalComment}</div>}
            {proofs && (proofs.photoKeys?.length > 0 || proofs.signerName || proofs.otpVerified !== null) && (
              <div className="small">Preuves : {[proofs.photoKeys?.length ? `${proofs.photoKeys.length} photo(s)` : null, proofs.signerName ? `signée par ${proofs.signerName}` : null,
                proofs.otpVerified ? 'code vérifié' : null, proofs.scanned?.length ? `${proofs.scanned.length} scan(s)` : null].filter(Boolean).join(' · ')}</div>
            )}
            {e.distanceMeters !== null && e.distanceMeters !== undefined && (
              <div className="small" style={{ color: e.distanceAlert ? 'var(--err)' : 'var(--muted)' }}>
                Écart avec l’adresse prévue : {num(e.distanceMeters, 0)} m{e.distanceAlert ? ' — alerte' : ''}
              </div>
            )}
          </li>
        );
      })}
    </ul>
  );
}

function FixForm({ order, onDone }) {
  const [f, setF] = useState({
    deliveryAddress: order.delivery.address?.formatted || '', deliveryPhone: order.delivery.contact?.phone || '', deliveryName: order.delivery.contact?.name || '',
    pickupAddress: order.pickup.address?.formatted || '', pickupPhone: order.pickup.contact?.phone || '',
    confirmNotDuplicate: false,
  });
  const a = useAction();
  const set = (k) => (e) => setF({ ...f, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value });
  const submit = () => a.run(async () => {
    const patch = {};
    for (const [k, v] of Object.entries(f)) {
      const old = { deliveryAddress: order.delivery.address?.formatted, deliveryPhone: order.delivery.contact?.phone, deliveryName: order.delivery.contact?.name,
        pickupAddress: order.pickup.address?.formatted, pickupPhone: order.pickup.contact?.phone }[k];
      if (k === 'confirmNotDuplicate' ? v : v !== (old || '')) patch[k] = v;
    }
    await gql(M.fixOrder, { orderId: order.id, patch: JSON.stringify(patch) });
    onDone();
  });
  const isDup = order.anomalies.some((x) => x.code === 'DUPLICATE');
  return (
    <div className="card">
      <h2>Corriger la demande</h2>
      <ErrorBox error={a.error} />
      <div className="form">
        <label className="f">Adresse de livraison<input value={f.deliveryAddress} onChange={set('deliveryAddress')} /></label>
        <label className="f">Destinataire<input value={f.deliveryName} onChange={set('deliveryName')} /></label>
        <label className="f">Téléphone du destinataire<input value={f.deliveryPhone} onChange={set('deliveryPhone')} /></label>
        <label className="f">Adresse de collecte<input value={f.pickupAddress} onChange={set('pickupAddress')} /></label>
        <label className="f">Téléphone de collecte<input value={f.pickupPhone} onChange={set('pickupPhone')} /></label>
      </div>
      {isDup && <label className="row small" style={{ marginTop: 10 }}><input type="checkbox" checked={f.confirmNotDuplicate} onChange={set('confirmNotDuplicate')} /> Ce n’est pas un doublon</label>}
      <div className="row" style={{ marginTop: 12 }}><button className="btn" disabled={a.busy} onClick={submit}>Valider la correction</button>
        <span className="small muted">Adresses re-géocodées et données re-vérifiées à l’enregistrement</span></div>
    </div>
  );
}

// Suivi par étapes, vue client (spec §11)
function ClientTracking({ orderId }) {
  const { data, error } = useLoad(async () => parseJson((await gql('query($orderId: ID!) { orderTracking(orderId: $orderId) }', { orderId })).orderTracking), [orderId]);
  if (error) return <ErrorBox error={error} />;
  if (!data) return null;
  return (
    <div className="card">
      <h2>Suivi</h2>
      <ul className="timeline">{data.steps.map((s) => (
        <li key={s.key} style={{ opacity: s.at ? 1 : 0.45 }}><b>{s.label}</b>{s.at && <span className="muted"> · {dateTime(s.at)}</span>}{s.detail && <div className="small">{s.detail}</div>}</li>
      ))}</ul>
      {data.otpCode && <div className="notice">Code de confirmation à donner au destinataire : <b>{data.otpCode}</b></div>}
      {data.proofs.length > 0 && <><h3>Preuves</h3><ul className="timeline">{data.proofs.map((p, i) => (
        <li key={i}>{EVENT_LABEL[p.type]} · {dateTime(p.at)}{p.signerName && ` · signé par ${p.signerName}`}{p.photoKeys.length > 0 && ` · ${p.photoKeys.length} photo(s)`}{p.comment && <div className="small">{p.comment}</div>}</li>
      ))}</ul></>}
    </div>
  );
}

export default function OrderDetail() {
  const { id } = useParams();
  const { session } = useAuth();
  const staff = ROLES.isDispatch(session.groups);
  const { data: order, error, reload } = useLoad(async () => (await gql(Q.getOrder, { id })).getOrder, [id]);
  const [modal, setModal] = useState(null);
  const [reason, setReason] = useState('');
  const [amount, setAmount] = useState('');
  const [openParcel, setOpenParcel] = useState(null);
  const a = useAction();

  if (error) return <ErrorBox error={error} />;
  if (!order) return <div className="empty">Chargement…</div>;
  const cancellable = ['AWAITING_PAYMENT', 'CREATED', 'TO_FIX', 'PLANNED'].includes(order.status);
  const labels = () => a.run(async () => { const r = parseJson((await gql(M.generateLabels, { orderId: order.id })).generateLabels); window.open(r.url, '_blank'); });
  const cancel = () => a.run(async () => { await gql(M.cancelOrder, { orderId: order.id, reason: reason || undefined }); setModal(null); reload(); });
  const gesture = () => a.run(async () => { await gql(M.commercialGesture, { orderId: order.id, amount: Number(amount), reason }); setModal(null); reload(); });

  return (
    <>
      <div className="head">
        <Link to={staff ? '/demandes' : '/'} className="muted">← Demandes</Link>
        <h1>{order.ref}</h1><Badge map={ORDER_STATUS} value={order.status} /><span className="spacer" />
        <button className="btn ghost" onClick={labels} disabled={a.busy}>Étiquettes PDF</button>
        {staff && order.paymentStatus === 'paid' && <button className="btn ghost" onClick={() => setModal('gesture')}>Geste commercial</button>}
        {cancellable && <button className="btn danger" onClick={() => setModal('cancel')}>Annuler</button>}
      </div>
      <ErrorBox error={a.error} />
      {order.anomalies?.length > 0 && <div className="error">{order.anomalies.map((x) => x.message).join(' · ')}</div>}
      {staff && ['TO_FIX', 'CREATED'].includes(order.status) && order.anomalies?.length > 0 && <FixForm order={order} onDone={reload} />}
      <div className="grid2">
        <div className="card"><Point title="Collecte" p={order.pickup} /></div>
        <div className="card"><Point title="Livraison" p={order.delivery} /></div>
      </div>
      <div className="card">
        <h2>Détails</h2>
        <div className="form">
          <div><div className="small muted">Client</div>{order.customerName || order.customerId}</div>
          <div><div className="small muted">Source</div>{order.source}{order.externalRef ? ` · ${order.externalRef}` : ''}</div>
          <div><div className="small muted">Colis</div>{order.parcelCount} × {order.size}{order.weightKg ? ` · ${num(order.weightKg)} kg` : ''}</div>
          <div><div className="small muted">Heure limite</div>{order.deadlineAt ? `${dateTime(order.deadlineAt)}${order.hardConstraint ? ' (stricte)' : ''}` : '—'}</div>
          <div><div className="small muted">Facturation</div>{order.billingMode === 'ACCOUNT' ? 'Compte' : `À la course · ${eur(order.priceTotal)}`}</div>
          <div><div className="small muted">Paiement</div>{order.paymentStatus || '—'}{order.refundedAmount ? ` · remboursé ${eur(order.refundedAmount)}` : ''}</div>
          {order.tourId && <div><div className="small muted">Tournée</div>{staff ? <Link to={`/tournees/${order.tourId}`}>Voir la tournée</Link> : 'Planifiée'}</div>}
        </div>
      </div>
      {!staff && <ClientTracking orderId={order.id} />}
      {staff && (
        <div className="card">
          <h2>Colis et historique</h2>
          <table><thead><tr><th>Colis</th><th>Code</th><th>Statut</th><th>Étiquette</th><th /></tr></thead>
            <tbody>{order.parcels.items.sort((x, y) => (x.index || 0) - (y.index || 0)).map((p) => (
              <tr key={p.id}><td>{p.index}/{p.total}</td><td><code>{p.code}</code></td><td><Badge map={PARCEL_STATUS} value={p.status} /></td>
                <td>{p.labelStatus === 'ACTIVE' ? 'Active' : p.labelStatus === 'RESERVED' ? 'En réserve' : 'Non utilisée'}</td>
                <td><button className="btn ghost small" onClick={() => setOpenParcel(openParcel === p.id ? null : p.id)}>{openParcel === p.id ? 'Masquer' : 'Historique'}</button></td></tr>
            ))}</tbody></table>
          {openParcel && <div style={{ marginTop: 12 }}><ParcelHistory parcel={{ id: openParcel }} /></div>}
          {order.rawInput && <details style={{ marginTop: 12 }}><summary className="small muted">Donnée brute reçue</summary><pre className="small">{JSON.stringify(parseJson(order.rawInput), null, 2)}</pre></details>}
        </div>
      )}
      {modal === 'cancel' && (
        <Modal title={`Annuler ${order.ref} ?`} onClose={() => setModal(null)} actions={<>
          <button className="btn ghost" onClick={() => setModal(null)}>Retour</button>
          <button className="btn danger" disabled={a.busy} onClick={cancel}>Annuler la demande</button></>}>
          {order.paymentStatus === 'paid' && <p>Le client sera remboursé de {eur(order.priceTotal)}.</p>}
          <label className="f">Motif<input value={reason} onChange={(e) => setReason(e.target.value)} /></label>
        </Modal>
      )}
      {modal === 'gesture' && (
        <Modal title="Geste commercial" onClose={() => setModal(null)} actions={<>
          <button className="btn ghost" onClick={() => setModal(null)}>Retour</button>
          <button className="btn" disabled={a.busy || !(Number(amount) > 0) || !reason} onClick={gesture}>Rembourser</button></>}>
          <p className="muted">Remboursement partiel sur la carte du client (payé : {eur(order.priceTotal)}).</p>
          <div className="form"><label className="f">Montant (€)<input type="number" step="0.5" value={amount} onChange={(e) => setAmount(e.target.value)} /></label>
            <label className="f">Motif<input value={reason} onChange={(e) => setReason(e.target.value)} /></label></div>
        </Modal>
      )}
    </>
  );
}

import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { gql } from '../lib/amplify';
import { Q } from '../lib/queries';
import { Badge, ErrorBox, useLoad } from '../components/ui';
import { ORDER_STATUS, dateTime, eur } from '../lib/format';

const TABS = [
  ['TO_FIX', 'À corriger'], ['CREATED', 'Prêtes à planifier'], ['PLANNED', 'Planifiées'], ['IN_PROGRESS', 'En cours'],
  ['DONE', 'Terminées'], ['PARTIALLY_FAILED', 'Échecs'], ['AWAITING_PAYMENT', 'Paiement en attente'], ['CANCELLED', 'Annulées'],
];

// Demandes et colis (spec §10) : recherche, filtres, statut détaillé ; file d'anomalies (spec §4)
export default function Orders() {
  const [status, setStatus] = useState('TO_FIX');
  const [q, setQ] = useState('');
  const nav = useNavigate();
  const { data, error, loading } = useLoad(async () => (await gql(Q.ordersByStatus, { status })).ordersByStatus.items, [status]);
  const list = useMemo(() => {
    const s = q.trim().toLowerCase();
    return (data || []).filter((o) => !s || [o.ref, o.externalRef, o.customerName, o.customerId, o.delivery.contact?.name, o.delivery.address?.formatted]
      .filter(Boolean).some((v) => v.toLowerCase().includes(s)));
  }, [data, q]);
  return (
    <>
      <div className="head"><h1>Demandes</h1><span className="spacer" />
        <input placeholder="Référence, client, destinataire, adresse" value={q} onChange={(e) => setQ(e.target.value)} style={{ width: 300 }} /></div>
      <div className="tabs">{TABS.map(([k, l]) => <button key={k} className={status === k ? 'on' : ''} onClick={() => setStatus(k)}>{l}</button>)}</div>
      <ErrorBox error={error} />
      <div className="card table-wrap">
        {loading ? <div className="empty">Chargement…</div> : list.length === 0 ? <div className="empty">Aucune demande</div> : (
          <table>
            <thead><tr><th>Demande</th><th>Client</th><th>Livraison</th><th>Colis</th><th>Limite</th><th>Prix</th><th>Statut</th></tr></thead>
            <tbody>{list.map((o) => (
              <tr key={o.id} className="click" onClick={() => nav(`/demandes/${o.id}`)}>
                <td><b>{o.ref}</b>{o.externalRef && <div className="small muted">Réf. client {o.externalRef}</div>}<div className="small muted">{dateTime(o.createdAt)}</div></td>
                <td>{o.customerName || o.customerId}<div className="small muted">{o.source}</div></td>
                <td>{o.delivery.contact?.name}<div className="small muted">{o.delivery.address?.formatted || '—'}</div>
                  {o.anomalies?.length > 0 && <div className="small" style={{ color: 'var(--err)' }}>{o.anomalies.map((a) => a.message).join(' ; ')}</div>}</td>
                <td>{o.parcelCount} × {o.size}</td>
                <td>{o.deadlineAt ? dateTime(o.deadlineAt) : '—'}</td>
                <td>{o.priceTotal ? eur(o.priceTotal) : <span className="muted">Compte</span>}</td>
                <td><Badge map={ORDER_STATUS} value={o.status} /></td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </div>
    </>
  );
}

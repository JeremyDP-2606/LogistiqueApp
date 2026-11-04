import { useNavigate } from 'react-router-dom';
import { gql } from '../lib/api';
import { Q } from '../lib/queries';
import { useAuth } from '../lib/auth';
import { Badge, ErrorBox, useLoad } from '../components/ui';
import { ORDER_STATUS, dateTime } from '../lib/format';

// Espace client professionnel : ses demandes uniquement (filtrage par les règles d'accès AppSync)
export default function ClientOrders() {
  const { session } = useAuth();
  const nav = useNavigate();
  const { data, error } = useLoad(async () => (await gql(Q.ordersByCustomer, { customerId: session.clientName })).ordersByCustomer.items);
  return (
    <>
      <div className="head"><h1>Mes demandes</h1></div>
      <ErrorBox error={error} />
      <div className="card table-wrap">
        {!data ? <div className="empty">Chargement…</div> : data.length === 0 ? <div className="empty">Aucune demande</div> : (
          <table><thead><tr><th>Demande</th><th>Votre référence</th><th>Destinataire</th><th>Statut</th></tr></thead>
            <tbody>{data.map((o) => (
              <tr key={o.id} className="click" onClick={() => nav(`/demandes/${o.id}`)}>
                <td><b>{o.ref}</b><div className="small muted">{dateTime(o.createdAt)}</div></td><td>{o.externalRef || '—'}</td>
                <td>{o.delivery.contact?.name}<div className="small muted">{o.delivery.address?.formatted}</div></td>
                <td><Badge map={ORDER_STATUS} value={o.status} /></td></tr>
            ))}</tbody></table>
        )}
      </div>
    </>
  );
}

import { Link } from 'react-router-dom';
import { gql } from '../lib/api';
import { Q } from '../lib/queries';
import { Badge, ErrorBox, useLoad } from '../components/ui';
import { TOUR_STATUS, today, time, num } from '../lib/format';

const items = (d, k) => d[k].items;

// Tableau de bord du dispatcher (spec §10) : tournées du jour, alertes, demandes à traiter
export default function Dashboard() {
  const { data, error, loading } = useLoad(async () => {
    const [toFix, ready, inProgress, assigned, accepted, planned, draft] = await Promise.all([
      gql(Q.ordersByStatus, { status: 'TO_FIX' }), gql(Q.ordersByStatus, { status: 'CREATED' }),
      ...['IN_PROGRESS', 'ASSIGNED', 'ACCEPTED', 'PLANNED', 'DRAFT'].map((status) => gql(Q.toursByStatus, { status })),
    ]);
    const tours = [inProgress, assigned, accepted, planned, draft].flatMap((d) => items(d, 'toursByStatus'));
    return { toFix: items(toFix, 'ordersByStatus'), ready: items(ready, 'ordersByStatus'), tours };
  });
  if (loading && !data) return <div className="empty">Chargement…</div>;
  if (error) return <ErrorBox error={error} />;
  const d = today();
  const todays = data.tours.filter((t) => t.date === d).sort((a, b) => a.startTime.localeCompare(b.startTime));
  const alerts = data.tours.flatMap((t) => (t.alerts || []).filter((a) => a.code === 'DEADLINE_MISSED').map((a) => ({ ...a, tour: t })));
  const incidents = data.tours.flatMap((t) => (t.incidents || []).filter((i) => i.status === 'OPEN').map((i) => ({ ...i, tour: t })));
  return (
    <>
      <div className="head"><h1>Tableau de bord</h1></div>
      <div className="stats">
        <div className={`stat ${data.toFix.length ? 'alert' : ''}`}><div className="l">Demandes à corriger</div><div className="v">{data.toFix.length}</div></div>
        <div className="stat"><div className="l">Prêtes à planifier</div><div className="v">{data.ready.length}</div></div>
        <div className="stat"><div className="l">Tournées du jour</div><div className="v">{todays.length}</div></div>
        <div className={`stat ${alerts.length ? 'alert' : ''}`}><div className="l">Heures limites menacées</div><div className="v">{alerts.length}</div></div>
      </div>
      <div className="grid2">
        <div className="card">
          <h2>Tournées du jour</h2>
          {todays.length === 0 ? <div className="empty">Aucune tournée aujourd’hui</div> : (
            <table><thead><tr><th>Tournée</th><th>Départ</th><th>Statut</th><th>Km</th></tr></thead>
              <tbody>{todays.map((t) => (
                <tr key={t.id}><td><Link to={`/tournees/${t.id}`}>{t.ref}</Link>{t.name ? <div className="small muted">{t.name}</div> : null}</td>
                  <td>{time(t.startTime)} · {t.slot === 'NIGHT' ? 'nuit' : 'jour'}</td><td><Badge map={TOUR_STATUS} value={t.status} /></td><td>{num(t.estimatedKm)}</td></tr>
              ))}</tbody></table>
          )}
        </div>
        <div className="card">
          <h2>Alertes</h2>
          {alerts.length + incidents.length + data.toFix.length === 0 && <div className="empty">Rien à signaler</div>}
          <ul className="timeline">
            {alerts.map((a, i) => <li key={`a${i}`}><b>{a.message}</b> · <Link to={`/tournees/${a.tour.id}`}>{a.tour.ref}</Link></li>)}
            {incidents.map((x, i) => <li key={`i${i}`}><b>Incident</b> : {x.motive} ({x.customerId}) · <Link to={`/tournees/${x.tour.id}`}>{x.tour.ref}</Link></li>)}
            {data.toFix.slice(0, 8).map((o) => <li key={o.id}><Link to={`/demandes/${o.id}`}>{o.ref}</Link> à corriger : {o.anomalies.map((a) => a.message).join(' ; ')}</li>)}
          </ul>
        </div>
      </div>
    </>
  );
}

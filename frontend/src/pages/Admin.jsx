import { useEffect, useState } from 'react';
import { api } from '../lib/api';
import { useAuth } from '../lib/auth';
import DeliveryMap from '../components/DeliveryMap';
import { eur, VEHICLE_ICON, VEHICLE_LABEL } from '../lib/format';

function Stat({ label, value }) {
  return <div className="card stat"><div className="muted small">{label}</div><div className="stat-value">{value}</div></div>;
}

export default function Admin() {
  const { socket } = useAuth();
  const [stats, setStats] = useState(null);
  const [couriers, setCouriers] = useState([]);
  const [users, setUsers] = useState([]);
  const [error, setError] = useState('');

  async function load() {
    try {
      const [s, c, u] = await Promise.all([api('/admin/stats'), api('/admin/couriers/live'), api('/admin/users')]);
      setStats(s); setCouriers(c.couriers); setUsers(u.users);
    } catch (e) { setError(e.message); }
  }

  useEffect(() => { load(); const t = setInterval(load, 15000); return () => clearInterval(t); }, []);
  useEffect(() => {
    if (!socket) return undefined;
    socket.on('job:updated', load);
    return () => socket.off('job:updated', load);
  }, [socket]);

  if (!stats) return <div className="center muted">{error || 'Chargement…'}</div>;

  return (
    <div className="container">
      <h2>Console d’exploitation</h2>
      <div className="stats">
        <Stat label="Courses totales" value={stats.jobs.total} />
        <Stat label="En attente" value={stats.jobs.pending} />
        <Stat label="En cours" value={stats.jobs.active} />
        <Stat label="Livrées" value={stats.jobs.delivered} />
        <Stat label="Chiffre d’affaires TTC" value={eur(stats.revenue.ttc)} />
        <Stat label="Rémunération coursiers" value={eur(stats.revenue.courierPayouts)} />
        <Stat label="Clients" value={stats.users.clients} />
        <Stat label="Coursiers en ligne" value={`${stats.users.couriersOnline} / ${stats.users.couriers}`} />
      </div>
      <div className="two-col">
        <div className="card">
          <h3>Flotte en ligne</h3>
          <DeliveryMap others={couriers.map((c) => ({ id: c.id, location: c.location, label: `${c.name} (${VEHICLE_LABEL[c.vehicle]})` }))} height={340} />
        </div>
        <div className="card">
          <h3>Coursiers</h3>
          <table className="table">
            <thead><tr><th>Nom</th><th>Véhicule</th><th>Note</th><th>Statut</th></tr></thead>
            <tbody>
              {users.filter((u) => u.role === 'courier').map((u) => {
                const live = couriers.find((c) => c.id === u.id);
                return (
                  <tr key={u.id}>
                    <td>{u.name}<div className="muted small">{u.email}</div></td>
                    <td>{VEHICLE_ICON[u.vehicle]} {VEHICLE_LABEL[u.vehicle]}</td>
                    <td>★ {u.rating}</td>
                    <td>{live ? (live.busy ? <span className="badge badge-info">En course</span> : <span className="badge badge-ok">Disponible</span>) : <span className="badge badge-muted">Hors ligne</span>}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

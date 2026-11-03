import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../lib/api';
import { useAuth } from '../lib/auth';
import StatusBadge from '../components/StatusBadge';
import { dateTime, eur, VEHICLE_ICON } from '../lib/format';

export default function Deliveries() {
  const { socket, user } = useAuth();
  const [tab, setTab] = useState('active');
  const [jobs, setJobs] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    api(`/jobs?status=${tab}`).then((d) => setJobs(d.jobs)).catch((e) => setError(e.message));
  }, [tab]);

  // Mise à jour en direct des statuts
  useEffect(() => {
    if (!socket) return undefined;
    const onUpdate = ({ job }) => setJobs((list) => list.map((j) => (j.id === job.id ? { ...j, ...job } : j)));
    socket.on('job:updated', onUpdate);
    return () => socket.off('job:updated', onUpdate);
  }, [socket]);

  return (
    <div className="container">
      <div className="row between">
        <h2>{user.role === 'admin' ? 'Toutes les courses' : 'Mes livraisons'}</h2>
        <Link className="btn" to="/new">+ Nouvelle livraison</Link>
      </div>
      <div className="tabs">
        {[['active', 'En cours'], ['done', 'Terminées'], ['', 'Toutes']].map(([k, l]) => (
          <button key={k} className={tab === k ? 'active' : ''} onClick={() => setTab(k)}>{l}</button>
        ))}
      </div>
      {error && <p className="error">{error}</p>}
      {jobs.length === 0 ? (
        <div className="card empty">Aucune livraison ici pour l’instant.</div>
      ) : (
        <div className="list">
          {jobs.map((j) => (
            <Link key={j.id} to={`/jobs/${j.id}`} className="card job-row">
              <div className="vehicle">{VEHICLE_ICON[j.vehicle]}</div>
              <div className="grow">
                <div className="row between"><strong>{j.ref}</strong><StatusBadge status={j.status} /></div>
                <div className="route"><span className="dot a" />{j.pickup.address}</div>
                <div className="route"><span className="dot b" />{j.dropoff.address}</div>
                <div className="muted small">{dateTime(j.createdAt)} · {j.distanceKm} km{user.role === 'admin' ? ` · ${j.clientName}` : ''}</div>
              </div>
              <div className="price">{eur(j.price?.ttc)}</div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

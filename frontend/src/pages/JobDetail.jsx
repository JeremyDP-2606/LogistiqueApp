import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../lib/api';
import { useAuth } from '../lib/auth';
import DeliveryMap from '../components/DeliveryMap';
import StatusBadge from '../components/StatusBadge';
import { STATUS, eur, time, dateTime, isActive, VEHICLE_LABEL, VEHICLE_ICON } from '../lib/format';

export default function JobDetail() {
  const { id } = useParams();
  const { socket, user } = useAuth();
  const [job, setJob] = useState(null);
  const [error, setError] = useState('');
  const [stars, setStars] = useState(5);
  const [comment, setComment] = useState('');

  useEffect(() => { api(`/jobs/${id}`).then((d) => setJob(d.job)).catch((e) => setError(e.message)); }, [id]);

  useEffect(() => {
    if (!socket) return undefined;
    const subscribe = () => socket.emit('job:subscribe', id);
    subscribe();
    socket.on('connect', subscribe); // ré-abonnement après reconnexion
    const onUpdate = ({ job: j }) => j.id === id && setJob((cur) => ({ ...cur, ...j, deliveryCode: cur?.deliveryCode }));
    const onLoc = ({ jobId, location }) => jobId === id &&
      setJob((cur) => (cur?.courier ? { ...cur, courier: { ...cur.courier, location } } : cur));
    socket.on('job:updated', onUpdate);
    socket.on('courier:location', onLoc);
    return () => {
      socket.emit('job:unsubscribe', id);
      socket.off('connect', subscribe);
      socket.off('job:updated', onUpdate);
      socket.off('courier:location', onLoc);
    };
  }, [socket, id]);

  async function cancel() {
    if (!window.confirm('Annuler cette livraison ?')) return;
    try { setJob((await api(`/jobs/${id}/cancel`, { method: 'POST', body: {} })).job); } catch (e) { setError(e.message); }
  }
  async function rate() {
    try { setJob((await api(`/jobs/${id}/rate`, { method: 'POST', body: { stars, comment } })).job); } catch (e) { setError(e.message); }
  }

  if (error && !job) return <div className="container"><p className="error">{error}</p></div>;
  if (!job) return <div className="center muted">Chargement…</div>;

  const canCancel = ['pending', 'assigned', 'picking_up'].includes(job.status) && (user.role === 'admin' || user.id === job.clientId);

  return (
    <div className="container two-col">
      <div>
        <div className="row between">
          <h2>{job.ref}</h2>
          <StatusBadge status={job.status} />
        </div>
        <DeliveryMap pickup={job.pickup} dropoff={job.dropoff} courier={isActive(job.status) ? job.courier?.location : null} />

        {job.deliveryCode && isActive(job.status) && (
          <div className="card code-card">
            <div>
              <strong>Code de remise</strong>
              <p className="muted small">Transmettez-le au destinataire : le coursier le lui demandera à la livraison.</p>
            </div>
            <div className="code">{job.deliveryCode}</div>
          </div>
        )}

        <div className="card">
          <h3>Itinéraire</h3>
          {[['a', 'Retrait', job.pickup], ['b', 'Livraison', job.dropoff]].map(([k, l, s]) => (
            <div key={k} className="stop">
              <span className={`dot ${k}`} />
              <div>
                <strong>{l}</strong> — {s.address}
                <div className="muted small">{[s.contactName, s.phone, s.instructions].filter(Boolean).join(' · ')}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <aside>
        <div className="card">
          <h3>Coursier</h3>
          {job.courier ? (
            <div className="row">
              <div className="avatar">{job.courier.name[0]}</div>
              <div className="grow">
                <strong>{job.courier.name}</strong>
                <div className="muted small">{VEHICLE_ICON[job.courier.vehicle]} {VEHICLE_LABEL[job.courier.vehicle]} · ★ {job.courier.rating}</div>
              </div>
              {job.courier.phone && <a className="btn btn-sm btn-ghost" href={`tel:${job.courier.phone}`}>Appeler</a>}
            </div>
          ) : job.status === 'pending' ? (
            <p className="muted"><span className="spinner" /> Nous cherchons un coursier à proximité…</p>
          ) : <p className="muted">—</p>}
        </div>

        <div className="card">
          <h3>Suivi</h3>
          <ol className="timeline">
            {job.history.map((h, i) => (
              <li key={i}><span className="muted small">{time(h.at)}</span> {STATUS[h.status]?.label}{h.reason ? ` — ${h.reason}` : ''}</li>
            ))}
          </ol>
        </div>

        <div className="card">
          <h3>Détails</h3>
          <dl className="details">
            <dt>Créée le</dt><dd>{dateTime(job.createdAt)}</dd>
            <dt>Véhicule</dt><dd>{VEHICLE_LABEL[job.vehicle]}</dd>
            <dt>Colis</dt><dd>{job.packageSize}{job.packageDescription ? ` — ${job.packageDescription}` : ''}</dd>
            <dt>Délai</dt><dd>{job.urgency === 'express' ? 'Express' : 'Standard'}</dd>
            <dt>Distance</dt><dd>{job.distanceKm} km</dd>
            {job.price && <><dt>Prix TTC</dt><dd><strong>{eur(job.price.ttc)}</strong></dd></>}
          </dl>
          {canCancel && <button className="btn btn-danger full" onClick={cancel}>Annuler la livraison</button>}
        </div>

        {job.status === 'delivered' && user.id === job.clientId && (
          <div className="card">
            <h3>Votre avis</h3>
            {job.rating ? (
              <p>{'★'.repeat(job.rating.stars)}{'☆'.repeat(5 - job.rating.stars)} {job.rating.comment}</p>
            ) : (
              <>
                <div className="stars">
                  {[1, 2, 3, 4, 5].map((n) => <button key={n} className={n <= stars ? 'on' : ''} onClick={() => setStars(n)}>★</button>)}
                </div>
                <div className="field"><input placeholder="Un commentaire ?" value={comment} onChange={(e) => setComment(e.target.value)} /></div>
                <button className="btn full" onClick={rate}>Envoyer</button>
              </>
            )}
          </div>
        )}
        {error && <p className="error">{error}</p>}
      </aside>
    </div>
  );
}

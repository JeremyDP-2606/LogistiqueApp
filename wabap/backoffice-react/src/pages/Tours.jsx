import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { gql } from '../lib/amplify';
import { M, Q } from '../lib/queries';
import { Badge, ErrorBox, Modal, useAction, useLoad } from '../components/ui';
import { TOUR_STATUS, date, time, num, today } from '../lib/format';

const STATUSES = ['DRAFT', 'PLANNED', 'ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'DONE', 'VALIDATED'];

// Tournées (spec §6) : liste et création
export default function Tours() {
  const nav = useNavigate();
  const [filter, setFilter] = useState('open');
  const { data, error, loading, reload } = useLoad(async () => {
    const lists = await Promise.all(STATUSES.map((status) => gql(Q.toursByStatus, { status })));
    const couriers = (await gql(Q.listCourierProfiles)).listCourierProfiles.items;
    const customers = (await gql(Q.listCustomers)).listCustomers.items;
    return { tours: lists.flatMap((l) => l.toursByStatus.items).sort((a, b) => b.startTime.localeCompare(a.startTime)), couriers, customers };
  });
  const [creating, setCreating] = useState(false);
  const [f, setF] = useState({ name: '', date: today(), slot: 'DAY', hour: '08:00', startAddress: '', lat: '', lng: '', courierId: '', dedicatedCustomerId: '' });
  const a = useAction();
  const courierName = (id) => data?.couriers.find((c) => c.id === id)?.name || (id ? id.slice(0, 8) : '—');
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });

  const create = () => a.run(async () => {
    // Heure saisie en heure locale (UTC−4 aux Antilles)
    const startTime = new Date(`${f.date}T${f.hour}:00-04:00`).toISOString();
    const t = (await gql(M.createTour, { input: JSON.stringify({
      name: f.name || undefined, date: f.date, slot: f.slot, startTime,
      start: { formatted: f.startAddress, latitude: Number(f.lat), longitude: Number(f.lng) },
      courierId: f.courierId || undefined, dedicatedCustomerId: f.dedicatedCustomerId || undefined,
    }) })).createTour;
    nav(`/tournees/${t.id}`);
  });

  const shown = (data?.tours || []).filter((t) => (filter === 'open' ? !['DONE', 'VALIDATED'].includes(t.status) : ['DONE', 'VALIDATED'].includes(t.status)));
  return (
    <>
      <div className="head"><h1>Tournées</h1><span className="spacer" /><button className="btn" onClick={() => setCreating(true)}>Nouvelle tournée</button></div>
      <div className="tabs"><button className={filter === 'open' ? 'on' : ''} onClick={() => setFilter('open')}>À venir et en cours</button>
        <button className={filter === 'done' ? 'on' : ''} onClick={() => setFilter('done')}>Terminées</button></div>
      <ErrorBox error={error} />
      <div className="card table-wrap">
        {loading ? <div className="empty">Chargement…</div> : shown.length === 0 ? <div className="empty">Aucune tournée</div> : (
          <table><thead><tr><th>Tournée</th><th>Date</th><th>Livreur</th><th>Demandes</th><th>Km estimés</th><th>Alertes</th><th>Statut</th></tr></thead>
            <tbody>{shown.map((t) => (
              <tr key={t.id} className="click" onClick={() => nav(`/tournees/${t.id}`)}>
                <td><b>{t.ref}</b>{t.name && <div className="small muted">{t.name}</div>}{t.dedicatedCustomerId && <div className="small muted">Dédiée · {t.dedicatedCustomerId}</div>}</td>
                <td>{date(t.date)} · {time(t.startTime)} {t.slot === 'NIGHT' ? '(nuit)' : ''}</td>
                <td>{courierName(t.courierId)}</td><td>{t.orderIds.length}</td><td>{num(t.estimatedKm)}</td>
                <td>{(t.alerts || []).length ? <span className="badge err">{t.alerts.length}</span> : '—'}</td>
                <td><Badge map={TOUR_STATUS} value={t.status} /></td></tr>
            ))}</tbody></table>
        )}
      </div>
      {creating && (
        <Modal title="Nouvelle tournée" onClose={() => setCreating(false)} actions={<>
          <button className="btn ghost" onClick={() => setCreating(false)}>Annuler</button>
          <button className="btn" disabled={a.busy || !f.lat || !f.lng} onClick={create}>Créer</button></>}>
          <ErrorBox error={a.error} />
          <div className="form">
            <label className="f">Nom (facultatif)<input value={f.name} onChange={set('name')} placeholder="Ex. Magazines du mardi" /></label>
            <label className="f">Date<input type="date" value={f.date} onChange={set('date')} /></label>
            <label className="f">Créneau<select value={f.slot} onChange={set('slot')}><option value="DAY">Jour</option><option value="NIGHT">Nuit</option></select></label>
            <label className="f">Heure de départ<input type="time" value={f.hour} onChange={set('hour')} /></label>
            <label className="f">Point de départ<input value={f.startAddress} onChange={set('startAddress')} placeholder="Dépôt" /></label>
            <label className="f">Latitude<input value={f.lat} onChange={set('lat')} placeholder="14.6160" /></label>
            <label className="f">Longitude<input value={f.lng} onChange={set('lng')} placeholder="-61.0300" /></label>
            <label className="f">Livreur<select value={f.courierId} onChange={set('courierId')}><option value="">Plus tard</option>
              {(data?.couriers || []).filter((c) => c.validated !== false).map((c) => <option key={c.id} value={c.id}>{c.name || c.id}</option>)}</select></label>
            <label className="f">Tournée dédiée à<select value={f.dedicatedCustomerId} onChange={set('dedicatedCustomerId')}><option value="">Mutualisée</option>
              {(data?.customers || []).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
          </div>
        </Modal>
      )}
    </>
  );
}

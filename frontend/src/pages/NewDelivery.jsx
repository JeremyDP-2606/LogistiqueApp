import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import AddressInput from '../components/AddressInput';
import DeliveryMap from '../components/DeliveryMap';
import { eur, SIZE_LABEL, VEHICLE_ICON } from '../lib/format';

const emptyStop = { address: '', lat: null, lng: null, contactName: '', phone: '', instructions: '' };

function StopForm({ title, value, onChange }) {
  const set = (k) => (e) => onChange({ ...value, [k]: e.target.value });
  return (
    <fieldset className="card">
      <legend>{title}</legend>
      <AddressInput label="Adresse" value={value} placeholder="Ex. 12 rue de la Paix, Paris"
        onSelect={(r) => onChange({ ...value, ...r })} />
      <div className="grid2">
        <div className="field"><label>Contact</label><input value={value.contactName} onChange={set('contactName')} /></div>
        <div className="field"><label>Téléphone</label><input value={value.phone} onChange={set('phone')} /></div>
      </div>
      <div className="field"><label>Instructions (étage, code…)</label><input value={value.instructions} onChange={set('instructions')} /></div>
    </fieldset>
  );
}

export default function NewDelivery() {
  const nav = useNavigate();
  const [pickup, setPickup] = useState(emptyStop);
  const [dropoff, setDropoff] = useState(emptyStop);
  const [packageSize, setSize] = useState('S');
  const [urgency, setUrgency] = useState('standard');
  const [description, setDescription] = useState('');
  const [quote, setQuote] = useState(null);
  const [vehicle, setVehicle] = useState(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const ready = pickup.lat && dropoff.lat;

  useEffect(() => {
    if (!ready) { setQuote(null); return; }
    setError('');
    api('/quotes', { method: 'POST', body: { pickup, dropoff, packageSize, urgency } })
      .then((q) => { setQuote(q); setVehicle((v) => (q.options.some((o) => o.vehicle === v) ? v : q.options[0]?.vehicle ?? null)); })
      .catch((e) => setError(e.message));
  }, [pickup.lat, pickup.lng, dropoff.lat, dropoff.lng, packageSize, urgency]); // eslint-disable-line react-hooks/exhaustive-deps

  async function order() {
    setBusy(true); setError('');
    try {
      const { job } = await api('/jobs', { method: 'POST', body: { pickup, dropoff, packageSize, urgency, vehicle, packageDescription: description } });
      nav(`/jobs/${job.id}`);
    } catch (e) { setError(e.message); } finally { setBusy(false); }
  }

  const selected = quote?.options.find((o) => o.vehicle === vehicle);

  return (
    <div className="container two-col">
      <div>
        <h2>Nouvelle livraison</h2>
        <StopForm title="🅰 Retrait" value={pickup} onChange={setPickup} />
        <StopForm title="🅱 Livraison" value={dropoff} onChange={setDropoff} />
        <fieldset className="card">
          <legend>Colis</legend>
          <div className="chips">
            {Object.entries(SIZE_LABEL).map(([k, l]) => (
              <button type="button" key={k} className={`chip ${packageSize === k ? 'active' : ''}`} onClick={() => setSize(k)}>
                <strong>{k}</strong> <span className="small">{l}</span>
              </button>
            ))}
          </div>
          <div className="field"><label>Description (optionnel)</label><input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Ex. 2 boîtes de pâtisseries" /></div>
          <div className="chips">
            <button type="button" className={`chip ${urgency === 'standard' ? 'active' : ''}`} onClick={() => setUrgency('standard')}>Standard · sous 2h</button>
            <button type="button" className={`chip ${urgency === 'express' ? 'active' : ''}`} onClick={() => setUrgency('express')}>⚡ Express · sous 45 min</button>
          </div>
        </fieldset>
      </div>
      <aside className="sticky">
        <DeliveryMap pickup={pickup} dropoff={dropoff} height={280} />
        <div className="card">
          <h3>Votre devis</h3>
          {!ready && <p className="muted">Renseignez les deux adresses pour obtenir un prix.</p>}
          {quote && <p className="muted small">Distance estimée : {quote.distanceKm} km</p>}
          {quote && quote.options.length === 0 && <p className="error">Aucun véhicule disponible pour cette distance ou taille.</p>}
          <div className="options">
            {quote?.options.map((o) => (
              <button key={o.vehicle} type="button" className={`option ${vehicle === o.vehicle ? 'active' : ''}`} onClick={() => setVehicle(o.vehicle)}>
                <span className="vehicle">{VEHICLE_ICON[o.vehicle]}</span>
                <span className="grow"><strong>{o.label}</strong><br /><span className="muted small">~{o.etaMinutes} min</span></span>
                <strong>{eur(o.price.ttc)}</strong>
              </button>
            ))}
          </div>
          {selected && <p className="muted small">dont TVA {eur(selected.price.tva)} · HT {eur(selected.price.ht)}</p>}
          {error && <p className="error">{error}</p>}
          <button className="btn full" disabled={!selected || busy || !pickup.address || !dropoff.address} onClick={order}>
            {busy ? 'Commande…' : selected ? `Commander · ${eur(selected.price.ttc)}` : 'Commander'}
          </button>
        </div>
      </aside>
    </div>
  );
}

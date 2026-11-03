import { useEffect, useRef, useState } from 'react';
import { api } from '../lib/api';

// Champ d'adresse avec autocomplétion (géocodage côté backend)
export default function AddressInput({ label, value, onSelect, placeholder }) {
  const [q, setQ] = useState(value?.address || '');
  const [results, setResults] = useState([]);
  const [open, setOpen] = useState(false);
  const [error, setError] = useState('');
  const timer = useRef();

  useEffect(() => { setQ(value?.address || ''); }, [value?.address]);

  function onChange(e) {
    const v = e.target.value;
    setQ(v);
    setError('');
    clearTimeout(timer.current);
    if (v.trim().length < 3) { setResults([]); return; }
    timer.current = setTimeout(async () => {
      try {
        const d = await api(`/geo/search?q=${encodeURIComponent(v)}`);
        setResults(d.results); setOpen(true);
      } catch (err) { setError(err.message); }
    }, 350);
  }

  return (
    <div className="field address-field">
      <label>{label}</label>
      <input value={q} onChange={onChange} placeholder={placeholder} onFocus={() => results.length && setOpen(true)}
        onBlur={() => setTimeout(() => setOpen(false), 150)} />
      {value?.lat && <small className="muted">📍 {value.lat.toFixed(5)}, {value.lng.toFixed(5)}</small>}
      {error && <small className="error">{error}</small>}
      {open && results.length > 0 && (
        <ul className="suggestions">
          {results.map((r) => (
            <li key={`${r.lat},${r.lng}`} onMouseDown={() => { onSelect(r); setQ(r.address); setOpen(false); }}>{r.address}</li>
          ))}
        </ul>
      )}
    </div>
  );
}

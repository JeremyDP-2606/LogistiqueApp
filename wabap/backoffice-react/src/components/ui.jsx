import { useCallback, useEffect, useState } from 'react';

export function Badge({ map, value }) {
  const [label, tone] = map[value] || [value, 'muted'];
  return <span className={`badge ${tone}`}>{label}</span>;
}

export function Modal({ title, children, onClose, actions }) {
  return (
    <div className="modal-bg" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal" role="dialog" aria-label={title}>
        <h2>{title}</h2>
        {children}
        <div className="actions">{actions}</div>
      </div>
    </div>
  );
}

export function ErrorBox({ error }) {
  return error ? <div className="error">{String(error.message || error)}</div> : null;
}

// Chargement asynchrone avec état d'erreur et rechargement
export function useLoad(fn, deps = []) {
  const [state, setState] = useState({ loading: true, data: null, error: null });
  const reload = useCallback(async () => {
    setState((s) => ({ ...s, loading: true }));
    try { setState({ loading: false, data: await fn(), error: null }); } catch (error) { setState({ loading: false, data: null, error }); }
  }, deps); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { reload(); }, [reload]);
  return { ...state, reload };
}

// Exécute une action et remonte l'erreur à l'écran
export function useAction() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const run = async (fn) => {
    setBusy(true); setError(null);
    try { return await fn(); } catch (e) { setError(e); return undefined; } finally { setBusy(false); }
  };
  return { busy, error, run, setError };
}

export function download(filename, content, type = 'text/csv;charset=utf-8') {
  const blob = new Blob(['﻿', content], { type });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

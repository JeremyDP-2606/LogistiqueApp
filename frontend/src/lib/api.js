const BASE = (import.meta.env.VITE_API_URL || '').replace(/\/$/, '');

export function getToken() {
  try { return localStorage.getItem('lg_token'); } catch { return null; }
}
export function setToken(t) {
  try { t ? localStorage.setItem('lg_token', t) : localStorage.removeItem('lg_token'); } catch { /* ignore */ }
}

export async function api(path, { method = 'GET', body } = {}) {
  const token = getToken();
  const res = await fetch(`${BASE}/api${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `Erreur ${res.status}`);
  return data;
}

export const SOCKET_URL = BASE || window.location.origin;

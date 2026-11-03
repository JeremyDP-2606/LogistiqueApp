import { createContext, useContext, useEffect, useMemo, useState } from 'react';
import { io } from 'socket.io-client';
import { api, getToken, setToken, SOCKET_URL } from './api';

const AuthCtx = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(Boolean(getToken()));
  const [socket, setSocket] = useState(null);

  useEffect(() => {
    if (!getToken()) return;
    api('/auth/me').then((d) => setUser(d.user)).catch(() => setToken(null)).finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!user) return undefined;
    const s = io(SOCKET_URL, { auth: { token: getToken() } });
    setSocket(s);
    return () => { s.close(); setSocket(null); };
  }, [user?.id]);

  const value = useMemo(() => ({
    user, loading, socket,
    async login(email, password) {
      const d = await api('/auth/login', { method: 'POST', body: { email, password } });
      setToken(d.token); setUser(d.user); return d.user;
    },
    async register(payload) {
      const d = await api('/auth/register', { method: 'POST', body: payload });
      setToken(d.token); setUser(d.user); return d.user;
    },
    logout() { setToken(null); setUser(null); },
  }), [user, loading, socket]);

  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>;
}

export const useAuth = () => useContext(AuthCtx);

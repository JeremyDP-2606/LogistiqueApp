import { createContext, useContext, useEffect, useState, useCallback } from 'react';
import { currentSession, signIn, signOut, completeNewPassword } from './cognito';

const AuthCtx = createContext(null);

// Rôles (spec §2)
export const ROLES = {
  isSuper: (g) => g.includes('wabap'),
  isAdmin: (g) => g.includes('wabap') || g.includes('admin'),
  isDispatch: (g) => ['wabap', 'admin', 'dispatch'].some((x) => g.includes(x)),
  isFinance: (g) => ['wabap', 'admin', 'finance'].some((x) => g.includes(x)),
  isClient: (g) => g.includes('client') && !['wabap', 'admin', 'dispatch', 'finance'].some((x) => g.includes(x)),
};

export function AuthProvider({ children }) {
  const [session, setSession] = useState(undefined);

  const load = useCallback(async () => {
    try {
      const s = await currentSession();
      const id = s?.getIdToken().decodePayload();
      if (!id) return setSession(null);
      setSession({
        sub: id.sub,
        email: id.email,
        name: id.given_name || id.email,
        clientName: id['custom:clientName'] || null,
        groups: id['cognito:groups'] || [],
      });
    } catch (e) {
      console.warn('Session indisponible :', e?.name || e);
      setSession(null);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const value = {
    session,
    async login(email, password) {
      if (await signIn(email, password) === 'NEW_PASSWORD') return 'NEW_PASSWORD';
      await load();
      return 'OK';
    },
    async setNewPassword(password) {
      await completeNewPassword(password);
      await load();
    },
    async logout() { signOut(); setSession(null); },
  };
  return <AuthCtx.Provider value={value}>{children}</AuthCtx.Provider>;
}

export const useAuth = () => useContext(AuthCtx);

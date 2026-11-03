import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';

export default function Login() {
  const { login } = useAuth();
  const nav = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setBusy(true); setError('');
    try { await login(email, password); nav('/'); } catch (err) { setError(err.message); } finally { setBusy(false); }
  }

  return (
    <form className="card narrow center-block" onSubmit={submit}>
      <h2>Connexion</h2>
      <div className="field"><label>Email</label><input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></div>
      <div className="field"><label>Mot de passe</label><input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required /></div>
      {error && <p className="error">{error}</p>}
      <button className="btn full" disabled={busy}>{busy ? 'Connexion…' : 'Se connecter'}</button>
      <p className="muted small">Pas de compte ? <Link to="/register">Créer un compte</Link></p>
      <p className="muted small">Démo : client@demo.fr / admin@demo.fr — mot de passe <code>demo1234</code></p>
    </form>
  );
}

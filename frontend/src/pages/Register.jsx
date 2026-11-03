import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';

export default function Register() {
  const { register } = useAuth();
  const nav = useNavigate();
  const [f, setF] = useState({ name: '', company: '', email: '', phone: '', password: '' });
  const [error, setError] = useState('');
  const set = (k) => (e) => setF({ ...f, [k]: e.target.value });

  async function submit(e) {
    e.preventDefault();
    setError('');
    try { await register({ ...f, role: 'client' }); nav('/new'); } catch (err) { setError(err.message); }
  }

  return (
    <form className="card narrow center-block" onSubmit={submit}>
      <h2>Créer un compte expéditeur</h2>
      <div className="field"><label>Nom complet</label><input value={f.name} onChange={set('name')} required /></div>
      <div className="field"><label>Entreprise (optionnel)</label><input value={f.company} onChange={set('company')} /></div>
      <div className="field"><label>Email</label><input type="email" value={f.email} onChange={set('email')} required /></div>
      <div className="field"><label>Téléphone</label><input value={f.phone} onChange={set('phone')} /></div>
      <div className="field"><label>Mot de passe</label><input type="password" minLength={6} value={f.password} onChange={set('password')} required /></div>
      {error && <p className="error">{error}</p>}
      <button className="btn full">Créer mon compte</button>
      <p className="muted small">Vous êtes coursier ? Inscrivez-vous depuis l’application mobile.</p>
      <p className="muted small">Déjà inscrit ? <Link to="/login">Connexion</Link></p>
    </form>
  );
}

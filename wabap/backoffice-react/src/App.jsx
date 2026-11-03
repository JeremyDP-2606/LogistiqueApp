import { useState } from 'react';
import { NavLink, Navigate, Route, Routes } from 'react-router-dom';
import { useAuth, ROLES } from './lib/auth';
import Dashboard from './pages/Dashboard';
import Orders from './pages/Orders';
import OrderDetail from './pages/OrderDetail';
import Import from './pages/Import';
import Tours from './pages/Tours';
import TourDetail from './pages/TourDetail';
import Customers from './pages/Customers';
import ProofProfiles from './pages/ProofProfiles';
import CommentPresets from './pages/CommentPresets';
import PriceGrids from './pages/PriceGrids';
import RateGrids from './pages/RateGrids';
import Earnings from './pages/Earnings';
import ClientOrders from './pages/ClientOrders';

function Login() {
  const { login, setNewPassword } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [step, setStep] = useState('LOGIN');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const submit = async (e) => {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      if (step === 'LOGIN') { if ((await login(email, password)) === 'NEW_PASSWORD') { setStep('NEW'); setPassword(''); } }
      else await setNewPassword(password);
    } catch (err) { setError(err.message); } finally { setBusy(false); }
  };
  return (
    <div className="login">
      <form className="card" onSubmit={submit}>
        <div className="row" style={{ marginBottom: 16 }}>
          <div className="logo" style={{ width: 36, height: 36, borderRadius: 10, background: 'var(--brand)', color: '#fff', display: 'grid', placeItems: 'center', fontWeight: 800 }}>W</div>
          <h1>Wabap</h1>
        </div>
        {step === 'NEW' && <div className="notice">Première connexion : choisissez votre mot de passe.</div>}
        {error && <div className="error">{error}</div>}
        {step === 'LOGIN' && <label className="f">E-mail<input id="email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>}
        <label className="f" style={{ marginTop: 10 }}>{step === 'LOGIN' ? 'Mot de passe' : 'Nouveau mot de passe'}
          <input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={8} /></label>
        <button className="btn" style={{ width: '100%', marginTop: 16 }} disabled={busy}>{busy ? 'Connexion…' : 'Se connecter'}</button>
      </form>
    </div>
  );
}

function Side() {
  const { session, logout } = useAuth();
  const g = session.groups;
  return (
    <nav className="side">
      <div className="brand"><span className="logo">W</span>Wabap</div>
      {ROLES.isDispatch(g) && <>
        <div className="group">Exploitation</div>
        <NavLink to="/" end>Tableau de bord</NavLink>
        <NavLink to="/demandes">Demandes</NavLink>
        <NavLink to="/import">Import CSV</NavLink>
        <NavLink to="/tournees">Tournées</NavLink>
      </>}
      {ROLES.isFinance(g) && <>
        <div className="group">Finance</div>
        <NavLink to="/remuneration">Rémunération</NavLink>
      </>}
      {ROLES.isAdmin(g) && <>
        <div className="group">Configuration</div>
        <NavLink to="/clients">Clients</NavLink>
        <NavLink to="/preuves">Profils de preuve</NavLink>
        <NavLink to="/commentaires">Commentaires</NavLink>
        <NavLink to="/tarifs">Tarifs des courses</NavLink>
        <NavLink to="/grilles-livreurs">Grilles livreurs</NavLink>
      </>}
      {ROLES.isClient(g) && <>
        <div className="group">Mon espace</div>
        <NavLink to="/" end>Mes demandes</NavLink>
      </>}
      <div className="who">
        {session.name}{session.clientName ? ` · ${session.clientName}` : ''}<br />
        <button className="btn ghost small" style={{ marginTop: 8 }} onClick={logout}>Déconnexion</button>
      </div>
    </nav>
  );
}

export default function App() {
  const { session, logout } = useAuth();
  if (session === undefined) return <div className="empty">Chargement…</div>;
  if (!session) return <Login />;
  const g = session.groups;
  if (!ROLES.isDispatch(g) && !ROLES.isFinance(g) && !ROLES.isClient(g)) {
    return <div className="login"><div className="card">Ce compte n’a pas accès au back-office. <button className="btn ghost" onClick={logout}>Déconnexion</button></div></div>;
  }
  return (
    <div className="app">
      <Side />
      <main className="main">
        <Routes>
          {ROLES.isClient(g) ? <Route path="/" element={<ClientOrders />} /> : <Route path="/" element={ROLES.isDispatch(g) ? <Dashboard /> : <Navigate to="/remuneration" />} />}
          {ROLES.isClient(g) && <Route path="/demandes/:id" element={<OrderDetail />} />}
          {ROLES.isDispatch(g) && <>
            <Route path="/demandes" element={<Orders />} />
            <Route path="/demandes/:id" element={<OrderDetail />} />
            <Route path="/import" element={<Import />} />
            <Route path="/tournees" element={<Tours />} />
            <Route path="/tournees/:id" element={<TourDetail />} />
          </>}
          {ROLES.isFinance(g) && <Route path="/remuneration" element={<Earnings />} />}
          {ROLES.isAdmin(g) && <>
            <Route path="/clients" element={<Customers />} />
            <Route path="/preuves" element={<ProofProfiles />} />
            <Route path="/commentaires" element={<CommentPresets />} />
            <Route path="/tarifs" element={<PriceGrids />} />
            <Route path="/grilles-livreurs" element={<RateGrids />} />
          </>}
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </main>
    </div>
  );
}

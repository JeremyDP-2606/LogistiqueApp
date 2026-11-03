import { Navigate, Route, Routes, NavLink, Link } from 'react-router-dom';
import { useAuth } from './lib/auth';
import Login from './pages/Login';
import Register from './pages/Register';
import Deliveries from './pages/Deliveries';
import NewDelivery from './pages/NewDelivery';
import JobDetail from './pages/JobDetail';
import Admin from './pages/Admin';
import Landing from './pages/Landing';

function Protected({ children, roles }) {
  const { user, loading } = useAuth();
  if (loading) return <div className="center muted">Chargement…</div>;
  if (!user) return <Navigate to="/login" replace />;
  if (roles && !roles.includes(user.role)) return <Navigate to="/" replace />;
  return children;
}

function Header() {
  const { user, logout } = useAuth();
  return (
    <header className="topbar">
      <Link to="/" className="brand"><span className="logo">L</span> LogistiqueApp</Link>
      <nav>
        {user?.role === 'client' && <>
          <NavLink to="/deliveries">Mes livraisons</NavLink>
          <NavLink to="/new" className="btn btn-sm">+ Nouvelle livraison</NavLink>
        </>}
        {user?.role === 'admin' && <>
          <NavLink to="/admin">Console</NavLink>
          <NavLink to="/deliveries">Toutes les courses</NavLink>
        </>}
        {user ? (
          <span className="user-menu">
            <span className="muted">{user.name}</span>
            <button className="link" onClick={logout}>Déconnexion</button>
          </span>
        ) : (
          <>
            <NavLink to="/login">Connexion</NavLink>
            <NavLink to="/register" className="btn btn-sm">Créer un compte</NavLink>
          </>
        )}
      </nav>
    </header>
  );
}

function Home() {
  const { user, loading } = useAuth();
  if (loading) return null;
  if (!user) return <Landing />;
  if (user.role === 'admin') return <Navigate to="/admin" replace />;
  if (user.role === 'courier') return (
    <div className="center card narrow">
      <h2>Espace coursier</h2>
      <p>Les coursiers utilisent l’application mobile pour recevoir et réaliser les courses.</p>
    </div>
  );
  return <Navigate to="/deliveries" replace />;
}

export default function App() {
  return (
    <>
      <Header />
      <main>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />
          <Route path="/deliveries" element={<Protected roles={['client', 'admin']}><Deliveries /></Protected>} />
          <Route path="/new" element={<Protected roles={['client', 'admin']}><NewDelivery /></Protected>} />
          <Route path="/jobs/:id" element={<Protected><JobDetail /></Protected>} />
          <Route path="/admin" element={<Protected roles={['admin']}><Admin /></Protected>} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
    </>
  );
}

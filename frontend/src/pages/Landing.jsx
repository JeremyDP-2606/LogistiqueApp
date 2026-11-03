import { Link } from 'react-router-dom';

export default function Landing() {
  return (
    <div className="landing">
      <section className="hero">
        <h1>Vos colis livrés en ville,<br />en moins d’une heure.</h1>
        <p>Commandez un coursier à vélo, scooter, voiture ou utilitaire. Prix immédiat, suivi en direct, code de remise sécurisé.</p>
        <div className="row">
          <Link className="btn" to="/register">Commencer à expédier</Link>
          <Link className="btn btn-ghost" to="/login">J’ai déjà un compte</Link>
        </div>
      </section>
      <section className="features">
        <div className="card"><h3>⚡ Devis instantané</h3><p>Le prix dépend de la distance, de la taille du colis et du délai. Pas de surprise.</p></div>
        <div className="card"><h3>📍 Suivi en temps réel</h3><p>Suivez votre coursier sur la carte, de l’enlèvement à la remise.</p></div>
        <div className="card"><h3>🔒 Remise sécurisée</h3><p>Le destinataire communique un code à 4 chiffres pour valider la livraison.</p></div>
        <div className="card"><h3>🚲 Flotte adaptée</h3><p>Du pli urgent à la palette : le bon véhicule pour chaque envoi.</p></div>
      </section>
    </div>
  );
}

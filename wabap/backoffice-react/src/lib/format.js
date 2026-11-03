// Formats d'affichage (heure locale des Antilles par défaut)
export const TZ = import.meta.env.VITE_TIMEZONE || 'America/Martinique';

export const eur = (n) => new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(n ?? 0);
export const num = (n, d = 1) => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: d }).format(n ?? 0);
export const dateTime = (s) => (s ? new Date(s).toLocaleString('fr-FR', { timeZone: TZ, dateStyle: 'short', timeStyle: 'short' }) : '—');
export const time = (s) => (s ? new Date(s).toLocaleTimeString('fr-FR', { timeZone: TZ, hour: '2-digit', minute: '2-digit' }) : '—');
export const date = (s) => (s ? new Date(s.length === 10 ? `${s}T12:00:00Z` : s).toLocaleDateString('fr-FR', { timeZone: TZ, weekday: 'short', day: 'numeric', month: 'short' }) : '—');
export const today = () => new Date().toLocaleDateString('sv-SE', { timeZone: TZ });

export const ORDER_STATUS = {
  AWAITING_PAYMENT: ['Paiement en attente', 'muted'],
  CREATED: ['Prête à planifier', 'info'],
  TO_FIX: ['À corriger', 'warn'],
  PLANNED: ['Planifiée', 'info'],
  IN_PROGRESS: ['En cours', 'info'],
  DONE: ['Terminée', 'ok'],
  PARTIALLY_FAILED: ['Partiellement échouée', 'err'],
  CANCELLED: ['Annulée', 'muted'],
};
export const PARCEL_STATUS = {
  AWAITING_PICKUP: ['En attente de collecte', 'muted'], PICKED_UP: ['Collecté', 'info'], IN_TRANSIT: ['En transit', 'info'],
  DELIVERED: ['Livré', 'ok'], FAILED: ['Échec', 'err'], RETURNING: ['En retour', 'warn'], RETURNED: ['Retourné', 'muted'],
};
export const TOUR_STATUS = {
  DRAFT: ['Brouillon', 'muted'], PLANNED: ['Planifiée', 'info'], ASSIGNED: ['Attribuée', 'info'], ACCEPTED: ['Acceptée', 'info'],
  IN_PROGRESS: ['En cours', 'warn'], DONE: ['Terminée', 'ok'], VALIDATED: ['Validée', 'ok'],
};
export const STOP_STATUS = { TODO: ['À faire', 'muted'], DONE: ['Fait', 'ok'], PARTIAL: ['Partiel', 'warn'], FAILED: ['Échec', 'err'] };
export const EARNING_STATUS = { TO_VALIDATE: ['À valider', 'warn'], VALIDATED: ['Validé', 'info'], PAID: ['Payé', 'ok'] };
export const EVENT_LABEL = {
  CREATED: 'Création', LABEL_GENERATED: 'Étiquette générée', LABEL_SENT: 'Étiquette envoyée', ASSIGNED_TO_TOUR: 'Affecté à une tournée',
  PICKED_UP: 'Collecté', DELIVERED: 'Livré', FAILED: 'Échec', INCIDENT: 'Incident', RETURNING: 'En retour', RETURNED: 'Retourné', CANCELLED: 'Annulé',
};
export const PROOF_LABEL = { scan: 'Scan', photo: 'Photo', signature: 'Signature', geoloc: 'Position GPS', otp: 'Code de confirmation' };

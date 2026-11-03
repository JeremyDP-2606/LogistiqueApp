export const STATUS = {
  pending:    { label: 'Recherche d’un coursier', tone: 'warn' },
  assigned:   { label: 'Coursier assigné',        tone: 'info' },
  picking_up: { label: 'En route vers le retrait', tone: 'info' },
  picked_up:  { label: 'Colis récupéré',          tone: 'info' },
  delivering: { label: 'En cours de livraison',   tone: 'info' },
  delivered:  { label: 'Livrée',                  tone: 'ok' },
  failed:     { label: 'Échec de livraison',      tone: 'err' },
  cancelled:  { label: 'Annulée',                 tone: 'muted' },
};
export const VEHICLE_LABEL = { bike: 'Vélo', motorbike: 'Scooter', car: 'Voiture', van: 'Utilitaire' };
export const VEHICLE_ICON = { bike: '🚲', motorbike: '🛵', car: '🚗', van: '🚐' };
export const SIZE_LABEL = { S: 'Petit (enveloppe, sac)', M: 'Moyen (carton à chaussures)', L: 'Grand (carton de déménagement)', XL: 'Très grand (meuble, palette)' };

export const eur = (n) => new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(n ?? 0);
export const dateTime = (s) => new Date(s).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' });
export const time = (s) => new Date(s).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
export const isActive = (s) => ['pending', 'assigned', 'picking_up', 'picked_up', 'delivering'].includes(s);

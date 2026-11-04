// Profils de preuve (spec §5) : cascade, agrégation par point, validation.
const PROOF_TYPES = ['scan', 'photo', 'signature', 'geoloc', 'otp'];
const PER_PARCEL = ['scan']; // exigées colis par colis
const PER_STOP = ['photo', 'signature', 'geoloc', 'otp']; // une seule fois pour tout le point

const NONE = Object.freeze({ scan: false, photo: false, signature: false, geoloc: false, otp: false });

function requirements(profile, kind) {
  const r = profile && profile[kind === 'PICKUP' ? 'pickup' : 'delivery'];
  return { ...NONE, ...(r || {}) };
}

// Cascade du plus général au plus précis : type de client → client → demande → colis.
// Le niveau le plus précis qui définit un profil l'emporte (en entier).
function resolveProfileId({ customerType, customer, order, parcel }) {
  return (parcel && parcel.proofProfileId)
    || (order && order.proofProfileId)
    || (customer && customer.proofProfileId)
    || (customerType && customerType.proofProfileId)
    || null;
}

// À un point regroupant plusieurs colis : preuves « par point » demandées une fois si au moins
// un colis l'exige ; scan demandé pour chaque colis qui l'exige.
function aggregateStop(parcelsWithProfiles, kind) {
  const perStop = { ...NONE };
  const scanParcelIds = [];
  for (const { parcel, profile } of parcelsWithProfiles) {
    const r = requirements(profile, kind);
    for (const t of PER_STOP) if (r[t]) perStop[t] = true;
    if (r.scan) scanParcelIds.push(parcel.id);
  }
  delete perStop.scan;
  return { perStop, scanParcelIds };
}

// submitted = { scannedParcelIds: [], photoKeys: [], signatureKey, signerName, position: {lat,lng}, otpOk }
function missingProofs(required, submitted, handledParcelIds) {
  const missing = [];
  const s = submitted || {};
  const scanned = new Set(s.scannedParcelIds || []);
  for (const id of required.scanParcelIds) {
    if (handledParcelIds.includes(id) && !scanned.has(id)) missing.push(`scan:${id}`);
  }
  const p = required.perStop;
  if (p.photo && !(s.photoKeys && s.photoKeys.length)) missing.push('photo');
  if (p.signature && !(s.signatureKey && s.signerName)) missing.push('signature');
  if (p.geoloc && !(s.position && Number.isFinite(s.position.latitude) && Number.isFinite(s.position.longitude))) missing.push('geoloc');
  if (p.otp && !s.otpOk) missing.push('otp');
  return missing;
}

const PROOF_LABELS = { scan: 'scan du colis', photo: 'photo', signature: 'signature avec nom', geoloc: 'position GPS', otp: 'code de confirmation' };
function describeMissing(missing) {
  const kinds = [...new Set(missing.map((m) => m.split(':')[0]))];
  return kinds.map((k) => PROOF_LABELS[k]).join(', ');
}

module.exports = { PROOF_TYPES, NONE, requirements, resolveProfileId, aggregateStop, missingProofs, describeMissing };

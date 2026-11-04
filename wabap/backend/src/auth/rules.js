// Application des règles @auth du schéma (autrefois appliquées par AppSync).
//   groups  : membres d'un des groupes Cognito
//   private : tout utilisateur connecté
//   owner   : l'élément appartient à l'utilisateur (item[ownerField] = valeur d'une revendication du jeton)
// Opérations : create, read, update, delete (read couvre get, list, index, relations, abonnements).
class Unauthorized extends Error {
  constructor(message = 'Accès refusé') { super(message); this.errorType = 'Unauthorized'; }
}

// Valeurs possibles d'une revendication pour comparer avec un champ propriétaire
function claimValues(identity, claim) {
  const c = identity.claims || {};
  const username = c['cognito:username'] || c.username || identity.username;
  switch (claim) {
    case 'sub::username': return [username && `${identity.sub}::${username}`, identity.sub, username].filter(Boolean);
    case 'sub': return [identity.sub];
    case 'username': case 'cognito:username': return [username].filter(Boolean);
    default: return c[claim] !== undefined && c[claim] !== null ? [String(c[claim])] : [];
  }
}
// Valeur écrite dans le champ propriétaire à la création
const claimValueForWrite = (identity, claim) => claimValues(identity, claim)[0];

// Droits d'une identité pour une opération sur un modèle : { all, owner: [règles propriétaire] }
function access(model, op, identity) {
  let all = false;
  const owner = [];
  for (const r of model.rules) {
    if (!r.operations.includes(op)) continue;
    if (r.allow === 'private') all = true;
    else if (r.allow === 'groups' && r.groups.some((g) => identity.groups.includes(g))) all = true;
    else if (r.allow === 'owner') owner.push(r);
  }
  return { all, owner };
}

function ownsItem(item, rules, identity) {
  return rules.some((r) => {
    const v = item?.[r.ownerField];
    const mine = claimValues(identity, r.identityClaim);
    if (Array.isArray(v)) return v.some((x) => mine.includes(String(x)));
    return v !== undefined && v !== null && mine.includes(String(v));
  });
}

// Lecture : élément autorisé ?
function canRead(model, item, identity) {
  const a = access(model, 'read', identity);
  return a.all || ownsItem(item, a.owner, identity);
}

// Champs protégés par une règle @auth de champ : masqués si l'identité n'y a pas droit
function maskFields(model, item, identity) {
  if (!item || !model.fieldAuth || !Object.keys(model.fieldAuth).length) return item;
  const out = { ...item };
  for (const [field, rules] of Object.entries(model.fieldAuth)) {
    const ok = rules.some((r) => (r.allow === 'private')
      || (r.allow === 'groups' && (r.groups || []).some((g) => identity.groups.includes(g))));
    if (!ok) out[field] = null;
  }
  return out;
}

// Création : contrôle et renseignement du champ propriétaire
function prepareCreate(model, input, identity) {
  const a = access(model, 'create', identity);
  const item = { ...input };
  // Champ propriétaire absent : renseigné avec la revendication de l'auteur, y compris pour un
  // membre d'un groupe autorisé (comportement historique populateOwnerFieldForStaticGroupAuth)
  for (const r of model.rules.filter((x) => x.allow === 'owner' && x.operations.includes('create'))) {
    const v = claimValueForWrite(identity, r.identityClaim);
    if ((item[r.ownerField] === undefined || item[r.ownerField] === null) && v !== undefined) item[r.ownerField] = v;
  }
  if (a.all) return item;
  if (!a.owner.length) throw new Unauthorized(`Création de ${model.name} non autorisée`);
  if (!ownsItem(item, a.owner, identity)) throw new Unauthorized(`Création de ${model.name} non autorisée`);
  return item;
}

// Mise à jour / suppression : l'élément existant doit être autorisé ; un propriétaire ne peut pas céder l'élément
function checkWrite(model, op, existing, input, identity) {
  const a = access(model, op, identity);
  if (a.all) return;
  if (!a.owner.length || !ownsItem(existing, a.owner, identity)) throw new Unauthorized(`${op === 'update' ? 'Modification' : 'Suppression'} de ${model.name} non autorisée`);
  if (input && op === 'update') {
    const after = { ...existing, ...input };
    if (!ownsItem(after, a.owner, identity)) throw new Unauthorized(`Changement de propriétaire de ${model.name} non autorisé`);
  }
}

// Opération personnalisée : groupes autorisés (null = tout utilisateur connecté)
function checkGroups(groups, identity, name) {
  if (groups && !groups.some((g) => identity.groups.includes(g))) throw new Unauthorized(`${name} : accès réservé (${groups.join(', ')})`);
}

module.exports = { Unauthorized, access, canRead, ownsItem, maskFields, prepareCreate, checkWrite, checkGroups, claimValues };

// Évaluation des filtres GraphQL (ModelXFilterInput, ModelXConditionInput, filtres d'abonnement),
// avec la même sémantique que l'API historique.
function cmp(a, b) {
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  return String(a).localeCompare(String(b));
}

function typeOf(v) {
  if (v === null) return '_null';
  if (Array.isArray(v)) return 'list';
  switch (typeof v) {
    case 'string': return 'string';
    case 'number': return 'number';
    case 'boolean': return 'bool';
    case 'object': return 'map';
    default: return undefined;
  }
}

function matchOp(v, op, x) {
  const present = v !== undefined && v !== null;
  switch (op) {
    case 'eq': return present ? (Array.isArray(v) ? JSON.stringify(v) === JSON.stringify(x) : v === x || String(v) === String(x)) : x === null;
    case 'ne': return !(present && (v === x || String(v) === String(x)));
    case 'le': return present && cmp(v, x) <= 0;
    case 'lt': return present && cmp(v, x) < 0;
    case 'ge': return present && cmp(v, x) >= 0;
    case 'gt': return present && cmp(v, x) > 0;
    case 'between': return present && cmp(v, x[0]) >= 0 && cmp(v, x[1]) <= 0;
    case 'beginsWith': return present && String(v).startsWith(x);
    case 'contains': return present && (Array.isArray(v) ? v.includes(x) : String(v).includes(x));
    case 'notContains': return !present || (Array.isArray(v) ? !v.includes(x) : !String(v).includes(x));
    case 'in': return present && x.includes(v);
    case 'notIn': return !present || !x.includes(v);
    case 'attributeExists': return x ? v !== undefined : v === undefined;
    case 'attributeType': return typeOf(v) === x;
    case 'size': {
      if (!present) return false;
      const n = Array.isArray(v) || typeof v === 'string' ? v.length : typeof v === 'object' ? Object.keys(v).length : 0;
      return Object.entries(x).every(([o, y]) => y === undefined || y === null || matchOp(n, o, y));
    }
    default: throw new Error(`Opérateur de filtre non géré : ${op}`);
  }
}

function matches(item, filter) {
  if (!filter) return true;
  return Object.entries(filter).every(([key, cond]) => {
    if (cond === undefined || cond === null) return true;
    if (key === 'and') return cond.every((f) => matches(item, f));
    if (key === 'or') return cond.length === 0 || cond.some((f) => matches(item, f));
    if (key === 'not') return !matches(item, cond);
    return Object.entries(cond).every(([op, x]) => x === undefined || x === null && op !== 'eq' ? true : matchOp(item?.[key], op, x));
  });
}

module.exports = { matches };

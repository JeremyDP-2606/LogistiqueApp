// Scalaires de l'API (mêmes noms et même transport que l'API historique) :
// dates et horaires en chaînes ISO 8601, AWSJSON transmis comme une chaîne JSON.
const { Kind, valueFromASTUntyped } = require('graphql');

const passthrough = (name, check) => ({
  serialize: (v) => (v instanceof Date ? v.toISOString() : v),
  parseValue: (v) => { if (check && !check(v)) throw new TypeError(`${name} invalide : ${v}`); return v; },
  parseLiteral: (ast) => {
    const v = ast.kind === Kind.INT || ast.kind === Kind.FLOAT ? Number(ast.value) : ast.value;
    if (check && !check(v)) throw new TypeError(`${name} invalide : ${v}`);
    return v;
  },
});

const isDate = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}(Z|[+-]\d{2}:\d{2})?$/.test(v);
const isDateTime = (v) => typeof v === 'string' && !Number.isNaN(Date.parse(v));
const isTime = (v) => typeof v === 'string' && /^\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})?$/.test(v);

const SCALARS = {
  AWSDate: passthrough('AWSDate', isDate),
  AWSDateTime: passthrough('AWSDateTime', isDateTime),
  AWSTime: passthrough('AWSTime', isTime),
  AWSTimestamp: passthrough('AWSTimestamp', (v) => Number.isInteger(Number(v))),
  AWSEmail: passthrough('AWSEmail', (v) => typeof v === 'string' && /^[^@\s]+@[^@\s]+$/.test(v)),
  AWSURL: passthrough('AWSURL', (v) => { try { new URL(v); return true; } catch { return false; } }),
  AWSPhone: passthrough('AWSPhone'),
  AWSIPAddress: passthrough('AWSIPAddress'),
  // En entrée : chaîne JSON → objet (stocké tel quel dans DynamoDB, comme l'API historique).
  // En sortie : objet → chaîne JSON ; une chaîne déjà sérialisée est renvoyée telle quelle.
  AWSJSON: {
    serialize: (v) => (typeof v === 'string' ? v : JSON.stringify(v)),
    parseValue: (v) => {
      if (typeof v !== 'string') return v;
      try { return JSON.parse(v); } catch { throw new TypeError('AWSJSON invalide'); }
    },
    parseLiteral: (ast) => {
      if (ast.kind === Kind.STRING) { try { return JSON.parse(ast.value); } catch { throw new TypeError('AWSJSON invalide'); } }
      return valueFromASTUntyped(ast);
    },
  },
};

function applyScalars(schema) {
  for (const [name, impl] of Object.entries(SCALARS)) {
    const t = schema.getType(name);
    if (t) Object.assign(t, impl);
  }
}

module.exports = { applyScalars };

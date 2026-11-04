// Compile le schéma des modèles (schema/schema.graphql) en :
//  - SDL de l'API GraphQL servie aux applications (même forme que l'API historique AppSync :
//    getX, listXs, index, createX/updateX/deleteX, onCreateX…, mêmes noms de types d'entrée) ;
//  - métadonnées des modèles (tables, index DynamoDB, relations, règles d'accès) utilisées
//    par les résolveurs génériques.
//
// Directives reconnues dans le schéma source :
//   @model(mutations: null, subscriptions: null)   type stocké dans une table DynamoDB
//   @auth(rules: [...])                            règles d'accès (groups, owner, private)
//   @index(name, queryField?, sortKeyFields?)      index secondaire global (+ requête)
//   @hasMany / @belongsTo / @hasOne                relations
//   @default(value)                                valeur par défaut à la création
//   @auth(groups: [...]) sur une opération         groupes Cognito autorisés
//   @subscribe(mutations: [...])                   abonnement temps réel déclenché par ces mutations
const { parse, Kind } = require('graphql');

const AWS_SCALARS = ['AWSDate', 'AWSTime', 'AWSDateTime', 'AWSTimestamp', 'AWSEmail', 'AWSJSON', 'AWSURL', 'AWSPhone', 'AWSIPAddress'];
const BASE_SCALARS = ['ID', 'String', 'Int', 'Float', 'Boolean'];

const lc = (s) => s[0].toLowerCase() + s.slice(1);
const uc = (s) => s[0].toUpperCase() + s.slice(1);
function plural(n) {
  if (/[^aeiou]y$/.test(n)) return `${n.slice(0, -1)}ies`;
  if (/is$/.test(n)) return n; // Colis
  if (/(s|x|z|ch|sh)$/.test(n)) return `${n}es`;
  return `${n}s`;
}

// ---------- Lecture des valeurs de directives ----------
function value(node) {
  switch (node.kind) {
    case Kind.STRING: case Kind.ENUM: return node.value;
    case Kind.INT: return Number(node.value);
    case Kind.FLOAT: return Number(node.value);
    case Kind.BOOLEAN: return node.value;
    case Kind.NULL: return null;
    case Kind.LIST: return node.values.map(value);
    case Kind.OBJECT: return Object.fromEntries(node.fields.map((f) => [f.name.value, value(f.value)]));
    default: throw new Error(`Valeur non gérée : ${node.kind}`);
  }
}
const directive = (node, name) => (node.directives || []).find((d) => d.name.value === name);
const directives = (node, name) => (node.directives || []).filter((d) => d.name.value === name);
const args = (d) => (d ? Object.fromEntries(d.arguments.map((a) => [a.name.value, value(a.value)])) : {});

// Type GraphQL d'un champ : { name, list, required, itemRequired }
function typeInfo(t) {
  let required = false, list = false, itemRequired = false;
  if (t.kind === Kind.NON_NULL_TYPE) { required = true; t = t.type; }
  if (t.kind === Kind.LIST_TYPE) {
    list = true; t = t.type;
    if (t.kind === Kind.NON_NULL_TYPE) { itemRequired = true; t = t.type; }
  }
  return { name: t.name.value, list, required, itemRequired };
}
const render = (ti, { forceOptional = false, rename } = {}) => {
  const n = rename || ti.name;
  const inner = ti.list ? `[${n}${ti.itemRequired ? '!' : ''}]` : n;
  return `${inner}${ti.required && !forceOptional ? '!' : ''}`;
};
const desc = (node) => (node.description ? `"""${node.description.value.replace(/"""/g, '\\"""')}"""\n` : '');

function compileSchema(source) {
  const doc = parse(source);
  const enums = new Map();
  const objects = new Map(); // types non modèles
  const modelNodes = new Map();
  const roots = { Query: [], Mutation: [], Subscription: [] };

  for (const def of doc.definitions) {
    if (def.kind === Kind.ENUM_TYPE_DEFINITION) enums.set(def.name.value, def);
    else if (def.kind === Kind.OBJECT_TYPE_DEFINITION) {
      const name = def.name.value;
      if (roots[name]) roots[name].push(...def.fields);
      else if (directive(def, 'model')) modelNodes.set(name, def);
      else objects.set(name, def);
    } else if (def.kind === Kind.SCALAR_TYPE_DEFINITION) {
      // scalaires déclarés : ignorés (les scalaires AWS sont fournis)
    } else {
      throw new Error(`Définition non gérée dans le schéma : ${def.kind}`);
    }
  }

  const isScalar = (n) => BASE_SCALARS.includes(n) || AWS_SCALARS.includes(n);
  const isEnum = (n) => enums.has(n);
  const isModel = (n) => modelNodes.has(n);

  // ---------- Modèles ----------
  const models = {};
  for (const [name, node] of modelNodes) {
    const modelArgs = args(directive(node, 'model'));
    const fields = [];
    for (const f of node.fields) {
      const ti = typeInfo(f.type);
      const field = { name: f.name.value, type: ti, node: f, description: f.description?.value };
      const hm = directive(f, 'hasMany'), bt = directive(f, 'belongsTo'), ho = directive(f, 'hasOne');
      if (hm) field.relation = { kind: 'hasMany', ...args(hm) };
      else if (bt) field.relation = { kind: 'belongsTo', ...args(bt) };
      else if (ho) field.relation = { kind: 'hasOne', ...args(ho) };
      else if (isModel(ti.name)) throw new Error(`${name}.${field.name} : relation sans directive`);
      const def = directive(f, 'default');
      if (def) field.default = args(def).value;
      const fauth = directive(f, 'auth');
      if (fauth) field.auth = args(fauth).rules;
      fields.push(field);
    }
    const rules = (args(directive(node, 'auth')).rules || []).map((r) => ({
      allow: r.allow,
      groups: r.groups || [],
      ownerField: r.ownerField || (r.allow === 'owner' ? 'owner' : undefined),
      identityClaim: r.identityClaim || (r.allow === 'owner' ? 'sub::username' : undefined),
      operations: r.operations || ['create', 'read', 'update', 'delete'],
    }));
    models[name] = {
      name,
      plural: plural(name),
      description: node.description?.value,
      mutations: modelArgs.mutations !== null,
      subscriptions: modelArgs.subscriptions !== null,
      fields,
      rules,
      indexes: [],
      relations: {},
      extraFields: [], // champs ajoutés (clés étrangères implicites, owner)
    };
  }

  // Champs owner manquants (addMissingOwnerFields)
  for (const m of Object.values(models)) {
    for (const r of m.rules) {
      if (r.allow === 'owner' && !m.fields.some((f) => f.name === r.ownerField) && !m.extraFields.some((f) => f.name === r.ownerField)) {
        m.extraFields.push({ name: r.ownerField, type: { name: 'String', list: false, required: false, itemRequired: false } });
      }
    }
  }

  // ---------- Index ----------
  const fieldOf = (m, n) => m.fields.find((f) => f.name === n) || m.extraFields.find((f) => f.name === n);
  for (const m of Object.values(models)) {
    for (const f of m.fields) {
      for (const d of directives(f.node, 'index')) {
        const a = args(d);
        const sortKey = (a.sortKeyFields || [])[0];
        if ((a.sortKeyFields || []).length > 1) throw new Error(`${m.name}.${f.name} : index à clé de tri composée non géré`);
        const queryField = a.queryField
          || `${lc(m.plural)}By${uc(f.name)}${sortKey ? `And${uc(sortKey)}` : ''}`;
        m.indexes.push({ name: a.name, hashKey: f.name, sortKey, queryField });
      }
    }
  }

  // ---------- Relations ----------
  const addFk = (m, name, required, own = false) => {
    if (fieldOf(m, name)) return;
    m.extraFields.push({ name, type: { name: 'ID', list: false, required, itemRequired: false }, implicitFk: !own });
  };
  // 1. hasMany (crée les clés étrangères implicites côté enfant)
  for (const m of Object.values(models)) {
    for (const f of m.fields.filter((x) => x.relation?.kind === 'hasMany')) {
      const child = models[f.type.name];
      if (!child) throw new Error(`${m.name}.${f.name} : modèle ${f.type.name} inconnu`);
      if (f.relation.indexName) {
        const ix = child.indexes.find((i) => i.name === f.relation.indexName);
        if (!ix) throw new Error(`${m.name}.${f.name} : index ${f.relation.indexName} absent de ${child.name}`);
        m.relations[f.name] = { kind: 'hasMany', model: child.name, index: ix.name, childKey: ix.hashKey, sortKey: ix.sortKey, parentKey: (f.relation.fields || ['id'])[0] };
      } else {
        const fk = `${lc(m.name)}${uc(f.name)}Id`;
        addFk(child, fk, false);
        const index = `gsi-${m.name}.${f.name}`;
        if (!child.indexes.some((i) => i.name === index)) child.indexes.push({ name: index, hashKey: fk, implicit: true });
        m.relations[f.name] = { kind: 'hasMany', model: child.name, index, childKey: fk, parentKey: 'id' };
      }
    }
  }
  // 2. belongsTo / hasOne
  for (const m of Object.values(models)) {
    for (const f of m.fields.filter((x) => ['belongsTo', 'hasOne'].includes(x.relation?.kind))) {
      const target = models[f.type.name];
      if (!target) throw new Error(`${m.name}.${f.name} : modèle ${f.type.name} inconnu`);
      let fk = (f.relation.fields || [])[0];
      if (!fk && f.relation.kind === 'belongsTo') {
        const back = Object.entries(target.relations).find(([, r]) => r.kind === 'hasMany' && r.model === m.name && r.index.startsWith('gsi-'));
        if (!back) throw new Error(`${m.name}.${f.name} : relation inverse introuvable`);
        fk = back[1].childKey;
      }
      if (!fk) {
        fk = `${lc(m.name)}${uc(f.name)}Id`;
        addFk(m, fk, f.type.required, true);
      }
      m.relations[f.name] = { kind: 'one', model: target.name, foreignKey: fk };
    }
  }

  // ---------- Opérations personnalisées ----------
  const operations = { Query: {}, Mutation: {}, Subscription: {} };
  for (const [root, list] of Object.entries(roots)) {
    for (const f of list) {
      const a = args(directive(f, 'auth'));
      operations[root][f.name.value] = {
        groups: a.groups || null,
        subscribe: root === 'Subscription' ? args(directive(f, 'subscribe')).mutations || [] : undefined,
        args: (f.arguments || []).map((x) => x.name.value),
      };
    }
  }

  // ---------- Génération du SDL ----------
  const out = [];
  out.push(...AWS_SCALARS.map((s) => `scalar ${s}`), '');
  for (const [, e] of enums) out.push(`${desc(e)}enum ${e.name.value} {\n${e.values.map((v) => `  ${v.name.value}`).join('\n')}\n}\n`);

  const stripField = (f) => `  ${f.description ? `"""${f.description.value}"""\n  ` : ''}${f.name.value}${f.arguments?.length ? `(${f.arguments.map((a) => `${a.name.value}: ${printType(a.type)}`).join(', ')})` : ''}: ${printType(f.type)}`;
  function printType(t) {
    if (t.kind === Kind.NON_NULL_TYPE) return `${printType(t.type)}!`;
    if (t.kind === Kind.LIST_TYPE) return `[${printType(t.type)}]`;
    return t.name.value;
  }
  for (const [name, o] of objects) out.push(`${desc(o)}type ${name} {\n${o.fields.map(stripField).join('\n')}\n}\n`);

  // Types d'entrée des types non modèles (ajoutés à la fin, seulement s'ils servent)
  const objectInputs = [];
  for (const [name, o] of objects) {
    objectInputs.push([name, `input ${name}Input {\n${o.fields.map((f) => {
      const ti = typeInfo(f.type);
      return `  ${f.name.value}: ${render(ti, { rename: objects.has(ti.name) ? `${ti.name}Input` : undefined })}`;
    }).join('\n')}\n}\n`]);
  }

  out.push(SHARED_INPUTS);
  for (const [name] of enums) out.push(`input Model${name}Input {\n  eq: ${name}\n  ne: ${name}\n}\n`);

  const filterType = (ti, sub = false) => {
    const p = sub ? 'ModelSubscription' : 'Model';
    if (isEnum(ti.name)) return `Model${ti.name}Input`;
    if (ti.name === 'ID') return `${p}IDInput`;
    if (ti.name === 'Int') return `${p}IntInput`;
    if (ti.name === 'Float') return `${p}FloatInput`;
    if (ti.name === 'Boolean') return `${p}BooleanInput`;
    if (isScalar(ti.name)) return `${p}StringInput`;
    return null; // types objets : non filtrables
  };
  const keyCondType = (ti) => (ti.name === 'Int' ? 'ModelIntKeyConditionInput' : ti.name === 'Float' ? 'ModelFloatKeyConditionInput' : ti.name === 'ID' ? 'ModelIDKeyConditionInput' : 'ModelStringKeyConditionInput');
  const queries = [], mutations = [], subscriptions = [];
  const usedKeyConds = new Set();
  const usedObjectInputs = new Set();

  for (const m of Object.values(models)) for (const f of m.fields) if (objects.has(f.type.name)) usedObjectInputs.add(f.type.name);
  for (const m of Object.values(models)) {
    const N = m.name;
    const stored = m.fields.filter((f) => !f.relation);
    const hasCreated = m.fields.some((f) => f.name === 'createdAt');
    const hasUpdated = m.fields.some((f) => f.name === 'updatedAt');
    const timestamps = [!hasCreated && 'createdAt', !hasUpdated && 'updatedAt'].filter(Boolean);
    const allScalars = [...stored, ...timestamps.map((t) => ({ name: t, type: { name: 'AWSDateTime', required: true } })), ...m.extraFields];

    // Type objet
    const typeFields = m.fields.map((f) => {
      const d = f.description ? `  """${f.description}"""\n` : '';
      if (f.relation?.kind === 'hasMany') {
        const r = m.relations[f.name];
        const child = models[r.model];
        const sk = r.sortKey ? `${r.sortKey}: ${keyCondType(fieldOf(child, r.sortKey)?.type || { name: 'AWSDateTime' })}, ` : '';
        if (sk) usedKeyConds.add(keyCondType(fieldOf(child, r.sortKey)?.type || { name: 'AWSDateTime' }));
        return `${d}  ${f.name}(${sk}filter: Model${f.type.name}FilterInput, sortDirection: ModelSortDirection, limit: Int, nextToken: String): Model${f.type.name}Connection`;
      }
      return `${d}  ${f.name}: ${render(f.type)}`;
    });
    timestamps.forEach((t) => typeFields.push(`  ${t}: AWSDateTime!`));
    m.extraFields.forEach((f) => typeFields.push(`  ${f.name}: ${render(f.type)}`));
    out.push(`${m.description ? `"""${m.description}"""\n` : ''}type ${N} {\n${typeFields.join('\n')}\n}\n`);
    out.push(`type Model${N}Connection {\n  items: [${N}]!\n  nextToken: String\n}\n`);

    // Filtres et conditions
    const ownerFields = new Set(m.rules.filter((r) => r.allow === 'owner').map((r) => r.ownerField));
    const filt = () => allScalars.map((f) => { const t = filterType(f.type); return t ? `  ${f.name}: ${t}` : null; }).filter(Boolean);
    out.push(`input Model${N}FilterInput {\n${filt().join('\n')}\n  and: [Model${N}FilterInput]\n  or: [Model${N}FilterInput]\n  not: Model${N}FilterInput\n}\n`);
    if (m.mutations) {
      // id n'est une condition possible que s'il sert de champ propriétaire
      const cond = filt().filter((l) => !l.startsWith('  id:') || ownerFields.has('id')).map((l) => (l.startsWith('  id:') ? '  id: ModelStringInput' : l));
      out.push(`input Model${N}ConditionInput {\n${cond.join('\n')}\n  and: [Model${N}ConditionInput]\n  or: [Model${N}ConditionInput]\n  not: Model${N}ConditionInput\n}\n`);
    }
    if (m.mutations && m.subscriptions) {
      // Même forme que l'API historique : énumérations filtrées comme des chaînes, champs propriétaires
      // en dernier, clés étrangères des relations hasMany du modèle
      const subLines = allScalars.filter((f) => !f.implicitFk && !ownerFields.has(f.name)).map((f) => {
        const t = isEnum(f.type.name) ? 'ModelSubscriptionStringInput' : filterType(f.type, true);
        return t ? `  ${f.name}: ${t}` : null;
      }).filter(Boolean);
      const fks = Object.values(m.relations).filter((r) => r.kind === 'hasMany' && r.parentKey === 'id' && !r.sortKey).map((r) => `  ${r.childKey}: ModelSubscriptionIDInput`);
      out.push(`input ModelSubscription${N}FilterInput {\n${subLines.join('\n')}\n  and: [ModelSubscription${N}FilterInput]\n  or: [ModelSubscription${N}FilterInput]\n${[...new Set(fks)].join('\n')}${fks.length ? '\n' : ''}${[...ownerFields].map((o) => `  ${o}: ModelStringInput`).join('\n')}\n}\n`);
    }

    // Requêtes
    queries.push(`  get${N}(id: ID!): ${N}`);
    queries.push(`  list${m.plural}(filter: Model${N}FilterInput, limit: Int, nextToken: String): Model${N}Connection`);
    for (const ix of m.indexes.filter((i) => !i.implicit)) {
      const hk = fieldOf(m, ix.hashKey).type;
      const sk = ix.sortKey && (fieldOf(m, ix.sortKey)?.type || { name: 'AWSDateTime' });
      if (sk) usedKeyConds.add(keyCondType(sk));
      queries.push(`  ${ix.queryField}(${ix.hashKey}: ${hk.name}!, ${sk ? `${ix.sortKey}: ${keyCondType(sk)}, ` : ''}sortDirection: ModelSortDirection, filter: Model${N}FilterInput, limit: Int, nextToken: String): Model${N}Connection`);
    }

    // Mutations
    if (m.mutations) {
      const inputField = (f, optional) => {
        const rename = objects.has(f.type.name) ? `${f.type.name}Input` : undefined;
        if (rename) usedObjectInputs.add(f.type.name);
        return `  ${f.name}: ${render(f.type, { forceOptional: optional, rename })}`;
      };
      const createFields = [
        '  id: ID',
        ...stored.filter((f) => f.name !== 'id').map((f) => inputField(f, ['createdAt', 'updatedAt'].includes(f.name) || f.default !== undefined ? false : false)),
        ...m.extraFields.map((f) => inputField(f, false)),
      ].map((l) => (/^\s+(createdAt|updatedAt):/.test(l) ? l.replace(/!$/, '') : l));
      out.push(`input Create${N}Input {\n${createFields.join('\n')}\n}\n`);
      out.push(`input Update${N}Input {\n  id: ID!\n${[...stored.filter((f) => f.name !== 'id'), ...m.extraFields].map((f) => inputField(f, true)).join('\n')}\n}\n`);
      out.push(`input Delete${N}Input {\n  id: ID!\n}\n`);
      for (const op of ['create', 'update', 'delete']) {
        mutations.push(`  ${op}${N}(input: ${uc(op)}${N}Input!, condition: Model${N}ConditionInput): ${N}`);
      }
    }
    if (m.subscriptions && m.mutations) {
      const ownerArgs = [...new Set(m.rules.filter((r) => r.allow === 'owner').map((r) => r.ownerField))].map((o) => `, ${o}: String`).join('');
      for (const op of ['Create', 'Update', 'Delete']) {
        subscriptions.push(`  on${op}${N}(filter: ModelSubscription${N}FilterInput${ownerArgs}): ${N}`);
        operations.Subscription[`on${op}${N}`] = { groups: null, subscribe: [`${lc(op)}${N}`], model: N, ownerArgs: m.rules.filter((r) => r.allow === 'owner').map((r) => r.ownerField) };
      }
    }
  }

  // Entrées d'objets imbriquées (ex. OrderPointInput → AddressInput)
  let grew = true;
  while (grew) {
    grew = false;
    for (const name of [...usedObjectInputs]) {
      for (const f of objects.get(name).fields) {
        const n = typeInfo(f.type).name;
        if (objects.has(n) && !usedObjectInputs.has(n)) { usedObjectInputs.add(n); grew = true; }
      }
    }
  }
  for (const [name, text] of objectInputs) if (usedObjectInputs.has(name)) out.push(text);
  const sharedAt = out.indexOf(SHARED_INPUTS);
  for (const k of ['ModelIDKeyConditionInput', 'ModelFloatKeyConditionInput', 'ModelIntKeyConditionInput', 'ModelStringKeyConditionInput']) {
    if (!usedKeyConds.has(k)) {
      const i = sharedAt;
      out[i] = out[i].replace(new RegExp(`\ninput ${k} \\{[^}]*\\}\n`), '\n');
    }
  }
  const custom = (root) => roots[root].map(stripField);
  out.push(`type Query {\n${[...custom('Query'), ...queries].join('\n')}\n}\n`);
  out.push(`type Mutation {\n${[...custom('Mutation'), ...mutations].join('\n')}\n}\n`);
  out.push(`type Subscription {\n${[...custom('Subscription'), ...subscriptions].join('\n')}\n}\n`);

  // Nettoyage des métadonnées exposées
  for (const m of Object.values(models)) {
    m.fieldAuth = Object.fromEntries(m.fields.filter((f) => f.auth).map((f) => [f.name, f.auth]));
    m.defaults = Object.fromEntries(m.fields.filter((f) => f.default !== undefined).map((f) => [f.name, f.default]));
    m.scalarFields = [...m.fields.filter((f) => !f.relation).map((f) => f.name), ...m.extraFields.map((f) => f.name), 'createdAt', 'updatedAt'];
    m.attributeTypes = Object.fromEntries([...m.fields.filter((f) => !f.relation), ...m.extraFields].map((f) => [f.name, f.type.name]));
    m.fields = m.fields.map(({ name, type, relation }) => ({ name, type, relation }));
  }
  return { sdl: out.join('\n'), models, operations };
}

const SHARED_INPUTS = `
enum ModelSortDirection {
  ASC
  DESC
}

enum ModelAttributeTypes {
  binary
  binarySet
  bool
  list
  map
  number
  numberSet
  string
  stringSet
  _null
}

input ModelSizeInput {
  ne: Int
  eq: Int
  le: Int
  lt: Int
  ge: Int
  gt: Int
  between: [Int]
}

input ModelStringInput {
  ne: String
  eq: String
  le: String
  lt: String
  ge: String
  gt: String
  contains: String
  notContains: String
  between: [String]
  beginsWith: String
  attributeExists: Boolean
  attributeType: ModelAttributeTypes
  size: ModelSizeInput
}

input ModelIDInput {
  ne: ID
  eq: ID
  le: ID
  lt: ID
  ge: ID
  gt: ID
  contains: ID
  notContains: ID
  between: [ID]
  beginsWith: ID
  attributeExists: Boolean
  attributeType: ModelAttributeTypes
  size: ModelSizeInput
}

input ModelIntInput {
  ne: Int
  eq: Int
  le: Int
  lt: Int
  ge: Int
  gt: Int
  between: [Int]
  attributeExists: Boolean
  attributeType: ModelAttributeTypes
}

input ModelFloatInput {
  ne: Float
  eq: Float
  le: Float
  lt: Float
  ge: Float
  gt: Float
  between: [Float]
  attributeExists: Boolean
  attributeType: ModelAttributeTypes
}

input ModelBooleanInput {
  ne: Boolean
  eq: Boolean
  attributeExists: Boolean
  attributeType: ModelAttributeTypes
}

input ModelSubscriptionStringInput {
  ne: String
  eq: String
  le: String
  lt: String
  ge: String
  gt: String
  contains: String
  notContains: String
  between: [String]
  beginsWith: String
  in: [String]
  notIn: [String]
}

input ModelSubscriptionIDInput {
  ne: ID
  eq: ID
  le: ID
  lt: ID
  ge: ID
  gt: ID
  contains: ID
  notContains: ID
  between: [ID]
  beginsWith: ID
  in: [ID]
  notIn: [ID]
}

input ModelSubscriptionIntInput {
  ne: Int
  eq: Int
  le: Int
  lt: Int
  ge: Int
  gt: Int
  between: [Int]
  in: [Int]
  notIn: [Int]
}

input ModelSubscriptionFloatInput {
  ne: Float
  eq: Float
  le: Float
  lt: Float
  ge: Float
  gt: Float
  between: [Float]
  in: [Float]
  notIn: [Float]
}

input ModelSubscriptionBooleanInput {
  ne: Boolean
  eq: Boolean
}

input ModelStringKeyConditionInput {
  eq: String
  le: String
  lt: String
  ge: String
  gt: String
  between: [String]
  beginsWith: String
}

input ModelIDKeyConditionInput {
  eq: ID
  le: ID
  lt: ID
  ge: ID
  gt: ID
  between: [ID]
  beginsWith: ID
}

input ModelIntKeyConditionInput {
  eq: Int
  le: Int
  lt: Int
  ge: Int
  gt: Int
  between: [Int]
}

input ModelFloatKeyConditionInput {
  eq: Float
  le: Float
  lt: Float
  ge: Float
  gt: Float
  between: [Float]
}
`;

module.exports = { compileSchema, plural };

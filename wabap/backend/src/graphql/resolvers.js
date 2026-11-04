// Résolveurs de l'API : génériques pour les modèles (lecture, écriture, index, relations, abonnements)
// et délégués aux opérations métier pour les champs déclarés dans Query / Mutation / Subscription.
const crypto = require('crypto');
const { buildSchema, GraphQLError } = require('graphql');
const { applyScalars } = require('./scalars');
const { matches } = require('./filter');
const R = require('../auth/rules');
const { ConditionFailed } = require('../data/common');

class ApiError extends GraphQLError {
  constructor(message, errorType) { super(message, { extensions: { errorType } }); this.errorType = errorType; }
}
const conditionFailed = () => new ApiError('The conditional request failed', 'DynamoDB:ConditionalCheckFailedException');

function needIdentity(ctx) {
  if (!ctx.identity) throw new ApiError('Authentification requise', 'UnauthorizedException');
  return ctx.identity;
}
const guard = (fn) => async (...a) => {
  try { return await fn(...a); } catch (e) {
    if (e instanceof R.Unauthorized) throw new ApiError(e.message, 'Unauthorized');
    if (e instanceof ConditionFailed) throw conditionFailed();
    throw e;
  }
};

// Identité au format attendu par les opérations métier
const businessIdentity = (identity) => ({
  sub: identity.sub,
  groups: identity.groups,
  name: identity.claims.given_name || identity.claims.name || null,
  email: identity.claims.email || null,
  phone: identity.claims.phone_number || null,
  clientName: identity.claims['custom:clientName'] || null,
});

function createResolvers({ compiled, store, pubsub, business, serverOps = {}, log = console }) {
  const { models, operations } = compiled;
  const schema = buildSchema(compiled.sdl);
  applyScalars(schema);
  const field = (type, name) => schema.getType(type).getFields()[name];
  const now = () => new Date().toISOString();

  // ---------- Lecture paginée avec filtre et contrôle d'accès ----------
  async function readPage(model, { index, hashKey, hashValue, sortKey, sortCond, sortDirection, filter, limit, nextToken }, identity) {
    const a = R.access(model, 'read', identity);
    if (!a.all && !a.owner.length) throw new R.Unauthorized(`Lecture de ${model.name} non autorisée`);
    const page = await store.page({ model: model.name, index, hashKey, hashValue, sortKey, sortCond, desc: sortDirection === 'DESC', limit: limit || 100, nextToken });
    const items = page.items
      .filter((x) => a.all || R.ownsItem(x, a.owner, identity))
      .filter((x) => matches(x, filter))
      .map((x) => R.maskFields(model, x, identity));
    return { items, nextToken: page.nextToken };
  }

  // ---------- Modèles ----------
  for (const model of Object.values(models)) {
    const N = model.name;
    const Q = schema.getType('Query').getFields();

    Q[`get${N}`].resolve = guard(async (_, { id }, ctx) => {
      const identity = needIdentity(ctx);
      const item = await store.get(N, id);
      if (!item) return null;
      if (!R.canRead(model, item, identity)) throw new R.Unauthorized(`Not Authorized to access get${N} on type ${N}`);
      return R.maskFields(model, item, identity);
    });
    Q[`list${model.plural}`].resolve = guard(async (_, args, ctx) => readPage(model, args, needIdentity(ctx)));
    for (const ix of model.indexes.filter((i) => !i.implicit)) {
      Q[ix.queryField].resolve = guard(async (_, args, ctx) => readPage(model, {
        index: ix.name, hashKey: ix.hashKey, hashValue: args[ix.hashKey], sortKey: ix.sortKey, sortCond: ix.sortKey ? args[ix.sortKey] : undefined,
        sortDirection: args.sortDirection, filter: args.filter, limit: args.limit, nextToken: args.nextToken,
      }, needIdentity(ctx)));
    }

    // Relations
    const T = schema.getType(N).getFields();
    for (const [name, r] of Object.entries(model.relations)) {
      const target = models[r.model];
      if (r.kind === 'hasMany') {
        T[name].resolve = guard(async (parent, args, ctx) => {
          const value = parent[r.parentKey];
          if (value === undefined || value === null) return { items: [], nextToken: null };
          return readPage(target, {
            index: r.index, hashKey: r.childKey, hashValue: value, sortKey: r.sortKey, sortCond: r.sortKey ? args[r.sortKey] : undefined,
            sortDirection: args.sortDirection, filter: args.filter, limit: args.limit, nextToken: args.nextToken,
          }, needIdentity(ctx));
        });
      } else {
        T[name].resolve = guard(async (parent, _, ctx) => {
          const id = parent[r.foreignKey];
          if (!id) return null;
          const item = await store.get(target.name, id);
          if (!item || !R.canRead(target, item, needIdentity(ctx))) return null;
          return R.maskFields(target, item, ctx.identity);
        });
      }
    }

    if (model.mutations) {
      const M = schema.getType('Mutation').getFields();
      M[`create${N}`].resolve = guard(async (_, { input, condition }, ctx) => {
        const identity = needIdentity(ctx);
        const at = now();
        let item = { ...input };
        for (const [k, v] of Object.entries(model.defaults)) if (item[k] === undefined || item[k] === null) item[k] = v;
        item = R.prepareCreate(model, item, identity);
        item = { ...item, id: item.id || crypto.randomUUID(), __typename: N, createdAt: item.createdAt || at, updatedAt: item.updatedAt || at };
        for (const k of Object.keys(item)) if (item[k] === null) delete item[k];
        if (condition && !matches({}, condition)) throw conditionFailed();
        await store.put(N, item, { ifNotExists: true });
        pubsub.publish(`create${N}`, item);
        return R.maskFields(model, item, identity);
      });
      M[`update${N}`].resolve = guard(async (_, { input, condition }, ctx) => {
        const identity = needIdentity(ctx);
        const existing = await store.get(N, input.id);
        if (!existing) throw conditionFailed();
        R.checkWrite(model, 'update', existing, input, identity);
        if (condition && !matches(existing, condition)) throw conditionFailed();
        const { id, ...patch } = input;
        patch.updatedAt = now();
        const item = await store.update(N, id, patch, {}, { removeNulls: true });
        pubsub.publish(`update${N}`, item);
        return R.maskFields(model, item, identity);
      });
      M[`delete${N}`].resolve = guard(async (_, { input, condition }, ctx) => {
        const identity = needIdentity(ctx);
        const existing = await store.get(N, input.id);
        if (!existing) throw conditionFailed();
        R.checkWrite(model, 'delete', existing, null, identity);
        if (condition && !matches(existing, condition)) throw conditionFailed();
        await store.delete(N, input.id);
        pubsub.publish(`delete${N}`, existing);
        return R.maskFields(model, existing, identity);
      });
    }
  }

  // ---------- Opérations personnalisées ----------
  for (const root of ['Query', 'Mutation']) {
    for (const [name, op] of Object.entries(operations[root])) {
      const f = field(root, name);
      f.resolve = guard(async (_, args, ctx) => {
        const identity = needIdentity(ctx);
        R.checkGroups(op.groups, identity, name);
        let result;
        if (serverOps[name]) result = await serverOps[name](args, ctx);
        else result = await business(name, businessIdentity(identity), args);
        if (root === 'Mutation') pubsub.publish(name, result);
        return result;
      });
    }
  }

  // ---------- Abonnements ----------
  const returnModel = (name) => {
    let t = field('Subscription', name).type;
    while (t.ofType) t = t.ofType;
    return models[t.name];
  };
  for (const [name, op] of Object.entries(operations.Subscription)) {
    const f = field('Subscription', name);
    const model = returnModel(name);
    f.subscribe = guard(async (_, args, ctx) => {
      const identity = needIdentity(ctx);
      R.checkGroups(op.groups, identity, name);
      const a = model ? R.access(model, 'read', identity) : { all: true, owner: [] };
      if (!a.all && !a.owner.length) throw new R.Unauthorized(`Abonnement ${name} non autorisé`);
      const { filter, ...eq } = args;
      return pubsub.iterator(op.subscribe, (payload) => payload
        && (a.all || R.ownsItem(payload, a.owner, identity))
        && matches(payload, filter)
        && Object.entries(eq).every(([k, v]) => v === undefined || v === null || String(payload[k]) === String(v)));
    });
    f.resolve = (payload, _, ctx) => (model ? R.maskFields(model, payload, ctx.identity) : payload);
  }

  return schema;
}

module.exports = { createResolvers, businessIdentity, ApiError };

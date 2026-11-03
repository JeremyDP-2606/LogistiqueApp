// Stockage en mémoire qui reproduit le comportement de lib/store.js (dont les conditions)
const { ConditionFailed } = require('../src/lib/store');

function createMemoryStore() {
  const tables = {};
  const t = (m) => (tables[m] = tables[m] || new Map());
  const clone = (x) => (x == null ? x : JSON.parse(JSON.stringify(x)));
  return {
    tables,
    async get(model, id) { return clone(t(model).get(id) || null); },
    async put(model, item) { t(model).set(item.id, clone(item)); return clone(item); },
    async update(model, id, patch, expect = {}) {
      const cur = t(model).get(id);
      if (!cur) throw new ConditionFailed('absent');
      for (const [k, v] of Object.entries(expect)) {
        const val = cur[k] ?? null;
        if (Array.isArray(v) ? !v.includes(val) : val !== v) throw new ConditionFailed(k);
      }
      Object.assign(cur, clone(patch));
      return clone(cur);
    },
    async query(model, index, key, value, { sortKey, sortValue } = {}) {
      return [...t(model).values()]
        .filter((x) => x[key] === value && (!sortKey || x[sortKey] === sortValue))
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
        .map(clone);
    },
  };
}
module.exports = { createMemoryStore };

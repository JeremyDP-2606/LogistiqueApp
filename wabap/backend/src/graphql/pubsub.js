// Diffusion temps réel en mémoire : une mutation publie son résultat, les abonnements à l'écoute le reçoivent.
// Une seule instance du serveur : au-delà, remplacer par un bus partagé (Redis, SNS…) avec la même interface.
function createPubSub() {
  const listeners = new Map(); // mutation → Set(fn)
  return {
    publish(mutation, payload) {
      for (const fn of listeners.get(mutation) || []) {
        try { fn(payload); } catch (e) { console.error('[temps réel]', e); }
      }
    },
    // Itérateur asynchrone sur les publications de plusieurs mutations
    iterator(mutations, accept = () => true) {
      const queue = [];
      let wake = null;
      let done = false;
      const push = (payload) => {
        if (done || !accept(payload)) return;
        queue.push(payload);
        if (wake) { wake(); wake = null; }
      };
      for (const m of mutations) {
        if (!listeners.has(m)) listeners.set(m, new Set());
        listeners.get(m).add(push);
      }
      const stop = () => {
        done = true;
        for (const m of mutations) listeners.get(m)?.delete(push);
        if (wake) { wake(); wake = null; }
      };
      return {
        [Symbol.asyncIterator]() { return this; },
        async next() {
          while (!queue.length && !done) await new Promise((r) => { wake = r; });
          if (done && !queue.length) return { value: undefined, done: true };
          return { value: queue.shift(), done: false };
        },
        async return() { stop(); return { value: undefined, done: true }; },
        async throw(e) { stop(); throw e; },
      };
    },
    count: () => [...listeners.values()].reduce((s, x) => s + x.size, 0),
  };
}

module.exports = { createPubSub };

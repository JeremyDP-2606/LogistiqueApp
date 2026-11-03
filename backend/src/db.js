// Stockage minimaliste en JSON (aucune base à installer).
// Remplaçable facilement par PostgreSQL/MongoDB : toutes les lectures/écritures passent par ce module.
const fs = require('fs');
const path = require('path');

function createDb(file = process.env.DB_FILE || path.join(__dirname, '..', 'data', 'db.json')) {
  const inMemory = file === ':memory:';
  let data = { users: [], jobs: [] };

  if (!inMemory && fs.existsSync(file)) {
    try {
      data = { users: [], jobs: [], ...JSON.parse(fs.readFileSync(file, 'utf8')) };
    } catch (e) {
      console.warn(`[db] fichier illisible (${e.message}), démarrage à vide`);
    }
  }

  let timer = null;
  function persist() {
    if (inMemory) return;
    clearTimeout(timer);
    timer = setTimeout(() => {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      const tmp = `${file}.tmp`;
      fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
      fs.renameSync(tmp, file);
    }, 50);
  }

  function collection(name) {
    return {
      all: () => data[name],
      find: (pred) => data[name].filter(pred),
      findOne: (pred) => data[name].find(pred),
      byId: (id) => data[name].find((x) => x.id === id),
      insert(doc) {
        data[name].push(doc);
        persist();
        return doc;
      },
      update(id, patch) {
        const doc = data[name].find((x) => x.id === id);
        if (!doc) return null;
        Object.assign(doc, typeof patch === 'function' ? patch(doc) || {} : patch);
        persist();
        return doc;
      },
    };
  }

  return {
    users: collection('users'),
    jobs: collection('jobs'),
    flush() {
      if (inMemory || !timer) return;
      clearTimeout(timer);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.writeFileSync(file, JSON.stringify(data, null, 2));
    },
  };
}

module.exports = { createDb };

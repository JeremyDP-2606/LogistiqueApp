// Toutes les requêtes GraphQL des applications (back-office React, back-office Vue V1, app Flutter)
// sont valides pour l'API du serveur : un champ renommé ou supprimé fait échouer ce test.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { parse, validate, buildSchema } = require('graphql');
const { compileSchema } = require('../src/schema/compile');

const ROOT = path.join(__dirname, '../..');
const schema = buildSchema(compileSchema(fs.readFileSync(path.join(__dirname, '../schema/schema.graphql'), 'utf8')).sdl);

function check(label, doc) {
  let ast;
  try { ast = parse(doc); } catch (e) { return [`${label} : ${e.message}`]; }
  return validate(schema, ast).map((e) => `${label} : ${e.message}`);
}

const isDocument = (v) => typeof v === 'string' && /^\s*(query|mutation|subscription)\b/.test(v);

async function documentsOfModule(file) {
  const mod = await import(path.join(ROOT, file));
  const out = [];
  const walk = (v, name) => {
    if (isDocument(v)) out.push([`${file} ${name}`, v]);
    else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) walk(x, `${name}.${k}`);
  };
  for (const [k, v] of Object.entries(mod)) walk(v, k);
  return out;
}

// Chaînes GraphQL littérales dans le code (sans interpolation)
function literalDocuments(dir, ext) {
  const out = [];
  const walk = (d) => {
    for (const f of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, f.name);
      if (f.isDirectory()) { if (!['node_modules', 'dist', 'graphql', 'build'].includes(f.name)) walk(p); continue; }
      if (!ext.some((e) => f.name.endsWith(e))) continue;
      const src = fs.readFileSync(p, 'utf8');
      const re = ext.includes('.dart')
        ? /r?'''([\s\S]*?)'''|r'((?:query|mutation|subscription)\b[^']*)'/g
        : /`((?:query|mutation|subscription)\b[^`]*)`|'((?:query|mutation|subscription)\b[^']*)'/g;
      for (const m of src.matchAll(re)) {
        const doc = m[1] || m[2];
        if (!doc || !isDocument(doc) || /\$\{/.test(doc)) continue;
        out.push([`${path.relative(ROOT, p)}`, doc.replace(/\\\$/g, '$')]);
      }
    }
  };
  walk(path.join(ROOT, dir));
  return out;
}

test('back-office React', async () => {
  const docs = [...await documentsOfModule('backoffice-react/src/lib/queries.js'), ...literalDocuments('backoffice-react/src', ['.js', '.jsx'])];
  assert.ok(docs.length > 20);
  assert.deepEqual(docs.flatMap(([l, d]) => check(l, d)), []);
});

test('back-office Vue V1', async () => {
  const docs = [];
  for (const f of ['queries', 'mutations', 'subscriptions']) docs.push(...await documentsOfModule(`backoffice/src/graphql/${f}.js`));
  docs.push(...literalDocuments('backoffice/src', ['.js', '.vue']));
  assert.ok(docs.length > 50);
  assert.deepEqual(docs.flatMap(([l, d]) => check(l, d)), []);
});

test('app Flutter', () => {
  const docs = literalDocuments('mobile/lib', ['.dart']);
  assert.ok(docs.length > 10);
  assert.deepEqual(docs.flatMap(([l, d]) => check(l, d)), []);
});

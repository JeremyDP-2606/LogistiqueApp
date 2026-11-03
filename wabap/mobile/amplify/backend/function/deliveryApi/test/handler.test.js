// Le schéma AppSync et le résolveur doivent déclarer exactement les mêmes opérations.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { OPERATIONS, handle, buildServices } = require('../src/index');
const { createMemoryStore } = require('./memoryStore');

const schema = fs.readFileSync(path.join(__dirname, '../../../api/wabap/schema.graphql'), 'utf8');

test('chaque opération @function du schéma a sa fonction métier, et réciproquement', () => {
  const declared = [...schema.matchAll(/^\s+(\w+)\([^)]*\)[^\n]*@function\(name: "deliveryApi-\$\{env\}"\)/gm)].map((m) => m[1]).sort();
  assert.deepEqual(declared, Object.keys(OPERATIONS).sort());
});

test('le résolveur masque les erreurs internes et exige une identité', async () => {
  const svc = buildServices({ store: createMemoryStore(), labelSecret: 's', now: () => new Date('2026-11-04T10:00:00Z') });
  await assert.rejects(handle({ fieldName: 'orderTracking', arguments: { orderId: 'x' } }, svc), /Authentification/);
  await assert.rejects(handle({ fieldName: 'orderTracking', arguments: { orderId: 'x' }, identity: { sub: 'u', claims: {} } }, svc), /introuvable/);
  const orig = console.error; console.error = () => {};
  const broken = { ...svc, tours: { ...svc.tours, courierView: async () => { throw new Error('détail interne'); } } };
  await assert.rejects(handle({ fieldName: 'courierTourView', arguments: { tourId: 't' }, identity: { sub: 'u', groups: ['livreur'] } }, broken), /Erreur serveur/);
  console.error = orig;
});

// Le schéma et les opérations métier doivent déclarer exactement les mêmes opérations.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { OPERATIONS, handle, buildServices } = require('../../src/delivery');
const { createMemoryStore } = require('./memoryStore');

const { compileSchema } = require('../../src/schema/compile');
const { SERVER_OPERATIONS } = require('../../src/graphql/serverOperations');

const { operations } = compileSchema(fs.readFileSync(path.join(__dirname, '../../schema/schema.graphql'), 'utf8'));

test('chaque opération personnalisée du schéma a sa fonction métier, et réciproquement', () => {
  const declared = [...Object.keys(operations.Query), ...Object.keys(operations.Mutation)]
    .filter((n) => !SERVER_OPERATIONS[n]).sort();
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

// Vérifie les requêtes DynamoDB réellement construites par src/data/dynamo.js (SDK AWS v3, envoi intercepté).
const { test } = require('node:test');
const assert = require('node:assert/strict');

test('requêtes DynamoDB construites par le store', async () => {
  const { DynamoDBDocumentClient } = require('@aws-sdk/lib-dynamodb');
  const sent = [];
  const reply = { value: {} };
  DynamoDBDocumentClient.prototype.send = async function (cmd) { sent.push(cmd); if (reply.error) { const e = reply.error; reply.error = null; throw e; } return reply.value; };
  const { createDynamoStore } = require('../../src/data/dynamo');
  const { ConditionFailed } = require('../../src/data/common');
  const store = createDynamoStore({ tableSuffix: '-abc-dev', region: 'us-east-1' });

  reply.value = { Attributes: { id: 'c1', status: 'ASSIGNED' } };
  const out = await store.update('Course', 'c1', { status: 'ASSIGNED', courierId: 'k1' }, { status: 'PENDING', courierId: null, kind: ['A', 'B'] });
  assert.equal(out.status, 'ASSIGNED');
  const u = sent.at(-1).input;
  assert.equal(u.TableName, 'Course-abc-dev');
  assert.deepEqual(u.Key, { id: 'c1' });
  assert.equal(u.UpdateExpression, 'SET #s0 = :s0, #s1 = :s1');
  assert.equal(u.ConditionExpression, 'attribute_exists(id) AND #c0 = :c0 AND (attribute_not_exists(#c1) OR #c1 = :null) AND #c2 IN (:c2_0, :c2_1)');
  assert.deepEqual(u.ExpressionAttributeNames, { '#s0': 'status', '#s1': 'courierId', '#c0': 'status', '#c1': 'courierId', '#c2': 'kind' });
  assert.deepEqual(u.ExpressionAttributeValues, { ':s0': 'ASSIGNED', ':s1': 'k1', ':c0': 'PENDING', ':null': null, ':c2_0': 'A', ':c2_1': 'B' });
  assert.equal(u.ReturnValues, 'ALL_NEW');

  const err = new Error('cond'); err.name = 'ConditionalCheckFailedException';
  reply.error = err;
  await assert.rejects(store.update('Course', 'c1', { status: 'X' }, { status: 'PENDING' }), ConditionFailed);

  reply.value = { Items: [{ id: 'c2' }] };
  const items = await store.query('Course', 'byZone', 'zone', 'ddgwm', { sortKey: 'status', sortValue: 'PENDING' });
  assert.deepEqual(items, [{ id: 'c2' }]);
  const q = sent.at(-1).input;
  assert.equal(q.IndexName, 'byZone');
  assert.equal(q.KeyConditionExpression, '#k = :k AND #s = :s');
  assert.deepEqual(q.ExpressionAttributeValues, { ':k': 'ddgwm', ':s': 'PENDING' });

  // Suppression et requête par plage (dates)
  await store.delete('Stop', 's1');
  assert.deepEqual(sent.at(-1).input, { TableName: 'Stop-abc-dev', Key: { id: 's1' }, ReturnValues: 'ALL_OLD' });
  reply.value = { Items: [] };
  await store.query('ParcelEvent', 'byDay', 'day', '2026-11-04', { sortKey: 'at', sortValue: ['2026-11-04T00:00', '2026-11-04T23:59'] });
  assert.equal(sent.at(-1).input.KeyConditionExpression, '#k = :k AND #s BETWEEN :s1 AND :s2');

  // La sérialisation réelle (marshalling) accepte ces valeurs, y compris null et les objets imbriqués
  const { marshall } = require('@aws-sdk/util-dynamodb');
  assert.ok(marshall(u.ExpressionAttributeValues, { removeUndefinedValues: true })[':null'].NULL);
});

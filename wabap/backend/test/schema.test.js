// Schéma : API publiée à jour, définition des tables conforme aux index.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { compileSchema } = require('../src/schema/compile');
const { definition } = require('../scripts/tables');

const source = fs.readFileSync(path.join(__dirname, '../schema/schema.graphql'), 'utf8');

test('schema/api.graphql est à jour (npm run schema)', () => {
  const printed = execFileSync(process.execPath, [path.join(__dirname, '../scripts/print-schema.js')], { encoding: 'utf8' });
  assert.equal(fs.readFileSync(path.join(__dirname, '../schema/api.graphql'), 'utf8'), printed);
});

test('relations et index implicites conformes aux tables historiques', () => {
  const { models } = compileSchema(source);
  assert.deepEqual(models.Mission.relations.subscribers, { kind: 'hasMany', model: 'Subscriber', index: 'gsi-Mission.subscribers', childKey: 'missionSubscribersId', parentKey: 'id' });
  assert.deepEqual(models.Subscriber.relations.mission, { kind: 'one', model: 'Mission', foreignKey: 'missionSubscribersId' });
  assert.deepEqual(models.Colis.relations.lastStatus, { kind: 'one', model: 'ColisStatus', foreignKey: 'colisLastStatusId' });
  assert.deepEqual(models.Tour.relations.stops, { kind: 'hasMany', model: 'Stop', index: 'byTour', childKey: 'tourId', sortKey: 'sequence', parentKey: 'id' });
  const colis = definition(models.Colis, 'Colis-x');
  assert.deepEqual(colis.GlobalSecondaryIndexes.map((g) => g.IndexName).sort(), ['byTourneeOrderPosition', 'bySubscriberOrderDate', 'gsi-Subscriber.colis', 'gsi-Tournee.colis'].sort());
  assert.deepEqual(colis.AttributeDefinitions.find((a) => a.AttributeName === 'position'), { AttributeName: 'position', AttributeType: 'N' });
});

test('requêtes d\'index nommées comme l\'API historique', () => {
  const { models } = compileSchema(source);
  assert.equal(models.Tour.indexes.find((i) => i.name === 'byCourier').queryField, 'toursByCourierIdAndStartTime');
  assert.equal(models.Order.indexes.find((i) => i.name === 'byStatus').queryField, 'ordersByStatus');
  assert.equal(models.Tournee.indexes.find((i) => i.name === 'byLivreurOrderDate').queryField, 'byLivreurOrderDate');
});

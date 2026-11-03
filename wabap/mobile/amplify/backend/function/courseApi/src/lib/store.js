// Accès DynamoDB aux tables générées par Amplify (<Modèle>-<apiId>-<env>).
// Le SDK AWS v3 est fourni par le runtime Lambda Node.js 24 : rien à installer.
class ConditionFailed extends Error {}

function createDynamoStore({ apiId, env, region }) {
  const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
  const { DynamoDBDocumentClient, GetCommand, PutCommand, UpdateCommand, QueryCommand } = require('@aws-sdk/lib-dynamodb');
  const doc = DynamoDBDocumentClient.from(new DynamoDBClient({ region }), {
    marshallOptions: { removeUndefinedValues: true },
  });
  const table = (model) => `${model}-${apiId}-${env}`;

  return {
    async get(model, id) {
      const r = await doc.send(new GetCommand({ TableName: table(model), Key: { id } }));
      return r.Item || null;
    },
    async put(model, item) {
      await doc.send(new PutCommand({ TableName: table(model), Item: item }));
      return item;
    },
    // Mise à jour conditionnelle : `expect` = { champ: valeurAttendue } (null = attribut absent ou nul)
    async update(model, id, patch, expect = {}) {
      const names = {}, values = {}, sets = [], conds = ['attribute_exists(id)'];
      Object.entries(patch).forEach(([k, v], i) => { names[`#s${i}`] = k; values[`:s${i}`] = v; sets.push(`#s${i} = :s${i}`); });
      Object.entries(expect).forEach(([k, v], i) => {
        names[`#c${i}`] = k;
        if (v === null) {
          values[':null'] = null;
          conds.push(`(attribute_not_exists(#c${i}) OR #c${i} = :null)`);
        } else if (Array.isArray(v)) {
          const keys = v.map((x, j) => { values[`:c${i}_${j}`] = x; return `:c${i}_${j}`; });
          conds.push(`#c${i} IN (${keys.join(', ')})`);
        } else { values[`:c${i}`] = v; conds.push(`#c${i} = :c${i}`); }
      });
      try {
        const r = await doc.send(new UpdateCommand({
          TableName: table(model), Key: { id },
          UpdateExpression: `SET ${sets.join(', ')}`,
          ConditionExpression: conds.join(' AND '),
          ExpressionAttributeNames: names, ExpressionAttributeValues: values,
          ReturnValues: 'ALL_NEW',
        }));
        return r.Attributes;
      } catch (e) {
        if (e.name === 'ConditionalCheckFailedException') throw new ConditionFailed('condition');
        throw e;
      }
    },
    // Requête sur un index secondaire : clé de partition (+ égalité facultative sur la clé de tri)
    async query(model, index, key, value, { sortKey, sortValue, limit = 100, desc = true } = {}) {
      const names = { '#k': key }, values = { ':k': value };
      let cond = '#k = :k';
      if (sortKey) { names['#s'] = sortKey; values[':s'] = sortValue; cond += ' AND #s = :s'; }
      const r = await doc.send(new QueryCommand({
        TableName: table(model), IndexName: index,
        KeyConditionExpression: cond, ExpressionAttributeNames: names, ExpressionAttributeValues: values,
        Limit: limit, ScanIndexForward: !desc,
      }));
      return r.Items || [];
    },
  };
}

module.exports = { createDynamoStore, ConditionFailed };

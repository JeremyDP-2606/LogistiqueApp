// Tables DynamoDB des modèles : vérification (check) ou création des tables et index manquants (create).
//   DYNAMODB_TABLE_SUFFIX=-<apiId>-<env> AWS_REGION=us-east-1 node scripts/tables.js check|create
// Les tables V1 existantes (créées autrefois par Amplify) sont conservées telles quelles.
const fs = require('fs');
const { DynamoDBClient, DescribeTableCommand, CreateTableCommand, UpdateTableCommand, waitUntilTableExists } = require('@aws-sdk/client-dynamodb');
const { compileSchema } = require('../src/schema/compile');
const { SCHEMA_FILE } = require('../src/services');

const NUMERIC = ['Int', 'Float', 'AWSTimestamp'];
const attrType = (model, name) => (NUMERIC.includes(model.attributeTypes[name]) ? 'N' : 'S');

function definition(model, tableName) {
  const attrs = new Map([['id', 'S']]);
  const gsis = model.indexes.map((ix) => {
    attrs.set(ix.hashKey, attrType(model, ix.hashKey));
    if (ix.sortKey) attrs.set(ix.sortKey, attrType(model, ix.sortKey));
    return {
      IndexName: ix.name,
      KeySchema: [{ AttributeName: ix.hashKey, KeyType: 'HASH' }, ...(ix.sortKey ? [{ AttributeName: ix.sortKey, KeyType: 'RANGE' }] : [])],
      Projection: { ProjectionType: 'ALL' },
    };
  });
  return {
    TableName: tableName,
    BillingMode: 'PAY_PER_REQUEST',
    KeySchema: [{ AttributeName: 'id', KeyType: 'HASH' }],
    AttributeDefinitions: [...attrs].map(([AttributeName, AttributeType]) => ({ AttributeName, AttributeType })),
    ...(gsis.length ? { GlobalSecondaryIndexes: gsis } : {}),
    DeletionProtectionEnabled: !process.env.DYNAMODB_ENDPOINT,
  };
}

async function main(mode = 'check') {
  const suffix = process.env.DYNAMODB_TABLE_SUFFIX;
  if (suffix === undefined) throw new Error('DYNAMODB_TABLE_SUFFIX manquant (ex. -nfdn7djf2fcbdjz44rvjidtaf4-prod)');
  const db = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1', ...(process.env.DYNAMODB_ENDPOINT ? { endpoint: process.env.DYNAMODB_ENDPOINT } : {}) });
  const { models } = compileSchema(fs.readFileSync(SCHEMA_FILE, 'utf8'));
  let problems = 0;
  for (const model of Object.values(models)) {
    const name = `${model.name}${suffix}`;
    const want = definition(model, name);
    let table = null;
    try { table = (await db.send(new DescribeTableCommand({ TableName: name }))).Table; } catch (e) { if (e.name !== 'ResourceNotFoundException') throw e; }
    if (!table) {
      problems++;
      if (mode === 'create') {
        await db.send(new CreateTableCommand(want));
        await waitUntilTableExists({ client: db, maxWaitTime: 300 }, { TableName: name });
        console.log(`créée      ${name}`);
      } else console.log(`MANQUANTE  ${name}`);
      continue;
    }
    const have = new Set((table.GlobalSecondaryIndexes || []).map((g) => g.IndexName));
    const missing = (want.GlobalSecondaryIndexes || []).filter((g) => !have.has(g.IndexName));
    if (!missing.length) { console.log(`ok         ${name}`); continue; }
    problems++;
    for (const gsi of missing) {
      if (mode !== 'create') { console.log(`INDEX MANQUANT ${name} : ${gsi.IndexName}`); continue; }
      const defs = want.AttributeDefinitions.filter((a) => gsi.KeySchema.some((k) => k.AttributeName === a.AttributeName));
      await db.send(new UpdateTableCommand({ TableName: name, AttributeDefinitions: defs, GlobalSecondaryIndexUpdates: [{ Create: gsi }] }));
      // un seul index créé à la fois par table : attendre qu'il soit actif
      for (;;) {
        const t = (await db.send(new DescribeTableCommand({ TableName: name }))).Table;
        if ((t.GlobalSecondaryIndexes || []).every((g) => g.IndexStatus === 'ACTIVE')) break;
        await new Promise((r) => setTimeout(r, 5000));
      }
      console.log(`index créé ${name} : ${gsi.IndexName}`);
    }
  }
  console.log(problems ? `${problems} table(s) à compléter${mode === 'create' ? ' : fait' : ' (npm run tables:create)'}` : 'Toutes les tables sont conformes au schéma');
  if (problems && mode !== 'create') process.exitCode = 1;
}

if (require.main === module) main(process.argv[2]).catch((e) => { console.error(e.message); process.exit(1); });
module.exports = { definition };

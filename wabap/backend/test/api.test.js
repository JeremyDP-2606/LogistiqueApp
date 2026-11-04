// API GraphQL générique : lecture, écriture, index, relations, filtres, pagination et règles d'accès.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { testServer } = require('./helpers');

const CREATE_MISSION = 'mutation($i: CreateMissionInput!) { createMission(input: $i) { id owner name } }';
const mission = (over = {}) => ({ owner: 'France-Antilles', name: 'Secteur A', livreurID: 'livreur-1', startLongitude: -61.07, startLatitude: 14.6, ...over });

test('création : identifiant, horodatage, valeur par défaut et propriétaire renseignés', async () => {
  const { ok, store } = testServer();
  const { createSubscriber: s } = await ok('wabap', 'mutation($i: CreateSubscriberInput!) { createSubscriber(input: $i) { id owner createdAt updatedAt } }',
    { i: { owner: 'France-Antilles', name: 'Dupont', type: 'subscriber', nb: 1 } });
  assert.match(s.id, /^[0-9a-f-]{36}$/);
  assert.ok(s.createdAt && s.createdAt === s.updatedAt);
  const raw = await store.get('Subscriber', s.id);
  assert.equal(raw.__typename, 'Subscriber');
  // Inscription : propriétaire (custom:clientName) déduit du jeton du client
  const { createInscription: i } = await ok('fa', 'mutation($i: CreateInscriptionInput!) { createInscription(input: $i) { owner livreurID } }', { i: { livreurID: 'livreur-1' } });
  assert.equal(i.owner, 'France-Antilles');
});

test('règles propriétaire : chaque client ne voit et ne modifie que ses données', async () => {
  const { ok, gql } = testServer();
  const { createMission: m } = await ok('fa', CREATE_MISSION, { i: mission() });
  await ok('wabap', CREATE_MISSION, { i: mission({ owner: 'Autre', name: 'Secteur B' }) });

  assert.equal((await ok('fa', '{ listMissions { items { name } } }')).listMissions.items.length, 1);
  assert.equal((await ok('autre', '{ listMissions { items { name } } }')).listMissions.items[0].name, 'Secteur B');
  assert.equal((await ok('wabap', '{ listMissions { items { name } } }')).listMissions.items.length, 2);

  const denied = await gql('autre', 'query($id: ID!) { getMission(id: $id) { name } }', { id: m.id });
  assert.equal(denied.errors[0].errorType, 'Unauthorized');
  const upd = await gql('autre', 'mutation($i: UpdateMissionInput!) { updateMission(input: $i) { id } }', { i: { id: m.id, name: 'pirate' } });
  assert.equal(upd.errors[0].errorType, 'Unauthorized');
  // Un propriétaire ne peut pas céder sa mission à un autre client
  const give = await gql('fa', 'mutation($i: UpdateMissionInput!) { updateMission(input: $i) { id } }', { i: { id: m.id, owner: 'Autre' } });
  assert.equal(give.errors[0].errorType, 'Unauthorized');
  // Création pour un autre client refusée
  const forged = await gql('fa', CREATE_MISSION, { i: mission({ owner: 'Autre' }) });
  assert.equal(forged.errors[0].errorType, 'Unauthorized');
});

test('règles de groupes, lecture pour tout utilisateur connecté et opérations restreintes', async () => {
  const { ok, gql } = testServer();
  await ok('admin', 'mutation { createProofProfile(input: { id: "standard", name: "Standard" }) { id } }');
  assert.equal((await ok('livreur', '{ listProofProfiles { items { id } } }')).listProofProfiles.items[0].id, 'standard');
  const r = await gql('livreur', 'mutation { createProofProfile(input: { id: "x", name: "X" }) { id } }');
  assert.equal(r.errors[0].errorType, 'Unauthorized');
  // Clients : lecture de leur seule fiche (ownerField id = custom:clientName)
  await ok('admin', 'mutation { createCustomer(input: { id: "France-Antilles", name: "FA", billingMode: ACCOUNT }) { id } }');
  await ok('admin', 'mutation { createCustomer(input: { id: "Autre", name: "Autre", billingMode: ACCOUNT }) { id } }');
  assert.deepEqual((await ok('fa', '{ listCustomers { items { id } } }')).listCustomers.items.map((c) => c.id), ['France-Antilles']);
  // Opération métier réservée à certains groupes
  const op = await gql('fa', 'mutation { optimizeTour(tourId: "t") { id } }');
  assert.equal(op.errors[0].errorType, 'Unauthorized');
});

test('champ protégé : commentaire interne masqué hors équipe Wabap', async () => {
  const { ok, store } = testServer();
  await store.put('ParcelEvent', { id: 'e1', parcelId: 'P1', customerId: 'France-Antilles', type: 'DELIVERED', at: '2026-11-04T10:00:00Z', day: '2026-11-04', comment: 'Laissé au gardien', internalComment: 'Client difficile', createdAt: 'x', updatedAt: 'x' });
  const q = '{ listParcelEvents { items { comment internalComment } } }';
  assert.equal((await ok('dispatch', q)).listParcelEvents.items[0].internalComment, 'Client difficile');
  const seen = (await ok('fa', q)).listParcelEvents.items[0];
  assert.equal(seen.comment, 'Laissé au gardien');
  assert.equal(seen.internalComment, null);
});

test('requêtes d\'index : clé de tri, sens, filtre et pagination', async () => {
  const { ok } = testServer();
  const { createMission: m } = await ok('wabap', CREATE_MISSION, { i: mission() });
  const { createTournee: t } = await ok('wabap', 'mutation($i: CreateTourneeInput!) { createTournee(input: $i) { id } }',
    { i: { owner: 'France-Antilles', name: 'T1', status: 'PENDING', startLongitude: 0, startLatitude: 0, livreurID: 'livreur-1', missionTourneeId: m.id } });
  for (const p of [3, 1, 2, 5, 4]) {
    await ok('wabap', 'mutation($i: CreateColisInput!) { createColis(input: $i) { id } }', { i: {
      owner: 'France-Antilles', tourneeColisId: t.id, position: p, address: `Adresse ${p}`, longitude: 0, latitude: 0, subscriberName: `Abonné ${p}`, colisLastStatusId: 'x', createdAt: `2026-11-04T10:0${p}:00Z`,
    } });
  }
  const q = 'query($t: ID!, $s: ModelSortDirection, $c: ModelIntKeyConditionInput, $n: String, $l: Int) { byTourneeOrderPosition(tourneeColisId: $t, position: $c, sortDirection: $s, limit: $l, nextToken: $n) { items { position } nextToken } }';
  const asc = (await ok('wabap', q, { t: t.id })).byTourneeOrderPosition.items.map((x) => x.position);
  assert.deepEqual(asc, [1, 2, 3, 4, 5]);
  const desc = (await ok('wabap', q, { t: t.id, s: 'DESC', c: { between: [2, 4] } })).byTourneeOrderPosition.items.map((x) => x.position);
  assert.deepEqual(desc, [4, 3, 2]);
  const p1 = (await ok('wabap', q, { t: t.id, l: 2 })).byTourneeOrderPosition;
  assert.deepEqual(p1.items.map((x) => x.position), [1, 2]);
  const p2 = (await ok('wabap', q, { t: t.id, l: 2, n: p1.nextToken })).byTourneeOrderPosition;
  assert.deepEqual(p2.items.map((x) => x.position), [3, 4]);
  // Relation hasMany paginée et filtrée depuis la tournée
  const rel = await ok('wabap', 'query($id: ID!) { getTournee(id: $id) { mission { name } colis(filter: { position: { ge: 4 } }) { items { position } } } }', { id: t.id });
  assert.equal(rel.getTournee.mission.name, 'Secteur A');
  assert.deepEqual(rel.getTournee.colis.items.map((x) => x.position).sort(), [4, 5]);
});

test('filtres : opérateurs, and / or / not, sur les listes', async () => {
  const { ok } = testServer();
  for (const [name, nb, unsub] of [['Alice', 1, false], ['Bob', 2, true], ['Bérénice', 3, false]]) {
    await ok('wabap', 'mutation($i: CreateSubscriberInput!) { createSubscriber(input: $i) { id } }', { i: { owner: 'France-Antilles', name, type: 'subscriber', nb, unsubscribed: unsub } });
  }
  const names = async (filter) => (await ok('wabap', 'query($f: ModelSubscriberFilterInput) { listSubscribers(filter: $f) { items { name } } }', { f: filter }))
    .listSubscribers.items.map((x) => x.name).sort();
  assert.deepEqual(await names({ nb: { gt: 1 } }), ['Bob', 'Bérénice']);
  assert.deepEqual(await names({ name: { beginsWith: 'B' }, unsubscribed: { ne: true } }), ['Bérénice']);
  assert.deepEqual(await names({ or: [{ nb: { eq: 1 } }, { nb: { eq: 3 } }] }), ['Alice', 'Bérénice']);
  assert.deepEqual(await names({ not: { name: { contains: 'o' } } }), ['Alice', 'Bérénice']);
  assert.deepEqual(await names({ address: { attributeExists: false }, nb: { between: [2, 3] } }), ['Bob', 'Bérénice']);
});

test('mise à jour : null supprime l\'attribut, condition respectée, élément absent refusé', async () => {
  const { ok, gql, store } = testServer();
  const { createSubscriber: s } = await ok('wabap', 'mutation($i: CreateSubscriberInput!) { createSubscriber(input: $i) { id } }',
    { i: { owner: 'France-Antilles', name: 'Alice', type: 'subscriber', nb: 1, phone1: '0696' } });
  await ok('wabap', 'mutation($i: UpdateSubscriberInput!) { updateSubscriber(input: $i) { id } }', { i: { id: s.id, phone1: null, nb: 2 } });
  const raw = await store.get('Subscriber', s.id);
  assert.equal('phone1' in raw, false);
  assert.equal(raw.nb, 2);
  const cond = await gql('wabap', 'mutation($i: UpdateSubscriberInput!, $c: ModelSubscriberConditionInput) { updateSubscriber(input: $i, condition: $c) { id } }',
    { i: { id: s.id, nb: 3 }, c: { nb: { eq: 99 } } });
  assert.equal(cond.errors[0].errorType, 'DynamoDB:ConditionalCheckFailedException');
  const missing = await gql('wabap', 'mutation { deleteSubscriber(input: { id: "nope" }) { id } }');
  assert.equal(missing.errors[0].errorType, 'DynamoDB:ConditionalCheckFailedException');
});

test('AWSJSON : chaîne en entrée, objet stocké, chaîne en sortie', async () => {
  const { ok, store } = testServer();
  await ok('admin', 'mutation($d: AWSJSON) { createCustomer(input: { id: "C1", name: "C", billingMode: ACCOUNT, defaults: $d }) { id } }', { d: JSON.stringify({ size: 'M' }) });
  assert.deepEqual((await store.get('Customer', 'C1')).defaults, { size: 'M' });
  const out = await ok('admin', '{ getCustomer(id: "C1") { defaults } }');
  assert.deepEqual(JSON.parse(out.getCustomer.defaults), { size: 'M' });
});

test('abonnements : diffusion filtrée selon les droits et les arguments', async () => {
  const { ok, services } = testServer();
  const { subscribe, parse } = require('graphql');
  const sub = async (who, query, variables) => subscribe({ schema: services.schema, document: parse(query), variableValues: variables, contextValue: { identity: require('./helpers').PEOPLE[who] } });
  const itFa = await sub('fa', 'subscription { onCreateMission { name owner } }');
  const itAutre = await sub('autre', 'subscription { onCreateMission { name owner } }');
  const pFa = itFa.next();
  const pAutre = Promise.race([itAutre.next(), new Promise((r) => setTimeout(() => r('rien'), 100))]);
  await ok('wabap', CREATE_MISSION, { i: mission() });
  assert.equal((await pFa).value.data.onCreateMission.name, 'Secteur A');
  assert.equal(await pAutre, 'rien');
  await itFa.return(); await itAutre.return();
  assert.equal(services.pubsub.count(), 0);
});

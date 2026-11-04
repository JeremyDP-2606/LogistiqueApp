// Fonctions V1 portées : réactions aux écritures, génération de tournée, imports, planning des missions.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const XLSX = require('xlsx');
const { testServer } = require('./helpers');
const { missionCron } = require('../src/scheduler');

async function seedTournee(store, positions = [1, 2, 3]) {
  await store.put('Tournee', { id: 'T1', owner: 'FA', name: 'T', status: 'PENDING', livreurID: 'l1', missionTourneeId: 'M1', startLatitude: 0, startLongitude: 0 });
  for (const p of positions) {
    const st = { id: `S${p}`, colisLogsId: `C${p}`, status: 'PENDING', createdAt: '2026-01-01T05:00:00.000Z', owner: 'FA' };
    await store.put('ColisStatus', st);
    await store.put('Colis', { id: `C${p}`, tourneeColisId: 'T1', position: p, owner: 'FA', lastStatus: st, colisLastStatusId: st.id });
  }
  await store.drain();
}
const status = (id, colis, s, at) => ({ __typename: 'ColisStatus', id, colisLogsId: colis, status: s, createdAt: at, updatedAt: at, owner: 'FA' });

test('statut de colis : dernier statut mis à jour et colis suivant passé « en cours »', async () => {
  const { store } = testServer();
  await seedTournee(store);
  await store.put('ColisStatus', status('S1b', 'C1', 'COMPLETED', '2026-01-02T09:00:00.000Z'));
  await store.drain();
  assert.equal((await store.get('Colis', 'C1')).lastStatus.status, 'COMPLETED');
  assert.equal((await store.get('Colis', 'C2')).lastStatus.status, 'IN_PROGRESS'); // statut créé par la réaction, lui-même répercuté
  assert.equal((await store.get('Colis', 'C3')).lastStatus.status, 'PENDING');
  // Un statut rejoué en retard ne remplace pas un statut plus récent
  await store.put('ColisStatus', status('S1c', 'C1', 'IN_PROGRESS', '2026-01-02T08:00:00.000Z'));
  await store.drain();
  assert.equal((await store.get('Colis', 'C1')).lastStatus.status, 'COMPLETED');
});

test('suppression d\'une tournée : colis et statuts supprimés', async () => {
  const { store } = testServer();
  await seedTournee(store);
  await store.delete('Tournee', 'T1');
  await store.drain();
  assert.equal(await store.get('Colis', 'C1'), null);
  assert.equal(await store.get('ColisStatus', 'S2'), null);
});

test('génération de tournée : ordre RouteXL, colis multiples, distance et durée', async () => {
  const calls = [];
  const fetchImpl = async (url, opts) => {
    calls.push(url);
    if (url.startsWith('https://api.routexl.com')) {
      const locs = JSON.parse(decodeURIComponent(opts.body.slice('locations='.length)));
      assert.equal(opts.headers.Authorization, 'Basic cle');
      // ordre inverse des abonnés
      const ordered = [locs[0], ...locs.slice(1, -1).reverse(), locs.at(-1)];
      return { ok: true, json: async () => ({ route: Object.fromEntries(ordered.map((l, i) => [i, { name: l.address }])) }) };
    }
    return { ok: true, json: async () => ({ routes: [{ overview_polyline: { points: 'abc' }, legs: [{ distance: { value: 1000 }, duration: { value: 120 } }] }] }) };
  };
  const { store, services } = testServer({ ROUTEXL_AUTH: 'cle', GOOGLE_MAPS_API_KEY: 'k' }, { fetchImpl });
  await store.put('Mission', { id: 'M1', owner: 'FA', name: 'Secteur A', livreurID: 'l1', startLatitude: 14.6, startLongitude: -61, startName: 'Dépôt', startTimeZone: 'America/Martinique' });
  await store.put('Subscriber', { id: 'A', owner: 'FA', name: 'Alice', nb: 1, unsubscribed: false, missionSubscribersId: 'M1', latitude: 14.61, longitude: -61.01, address: '1 rue A', type: 'subscriber' });
  await store.put('Subscriber', { id: 'B', owner: 'FA', name: 'Bob', nb: 2, unsubscribed: false, missionSubscribersId: 'M1', latitude: 14.62, longitude: -61.02, address: '2 rue B', type: 'subscriber' });
  await store.put('Subscriber', { id: 'X', owner: 'FA', name: 'Désabonné', nb: 1, unsubscribed: true, missionSubscribersId: 'M1', latitude: 1, longitude: 1, type: 'subscriber' });
  const t = await services.v1.tournees.generate({ missionId: 'M1' });
  await store.drain();
  assert.match(t.name, /^Secteur A du /);
  assert.equal(t.nbColis, 3);
  assert.equal(t.distance, 2000); // un trajet par abonné (le 2e colis de Bob est au même endroit)
  assert.equal(t.duree, 120 * 2 + 60 * 3);
  const colis = await store.query('Colis', 'byTourneeOrderPosition', 'tourneeColisId', t.id);
  const byPos = colis.sort((a, b) => a.position - b.position);
  assert.deepEqual(byPos.map((c) => c.subscriberName), ['Bob', 'Bob', 'Alice']);
  assert.equal(byPos[0].lastStatus.status, 'PENDING');
  assert.equal(calls.filter((u) => u.includes('routexl')).length, 1);
});

test('import CSV : création, mise à jour, désinscription et rattachement au secteur', async () => {
  const { store, services } = testServer({ IMPORT_REPORT_EMAILS: 'rapport@exemple.fr', REPORT_SENDER: 'rapport@wabap.fr' });
  await store.put('Mission', { id: 'M1', owner: 'FA', name: 'Sect.1', livreurID: 'l1' });
  await store.put('Subscriber', { id: 'old', owner: 'FA', numabo: '100', name: 'Ancien nom', nb: 1, type: 'subscriber', unsubscribed: true });
  await store.put('Subscriber', { id: 'gone', owner: 'FA', numabo: '999', name: 'Parti', nb: 1, type: 'subscriber', unsubscribed: false, missionSubscribersId: 'M1' });
  await store.put('Subscriber', { id: 'other', owner: 'Autre', numabo: '555', name: 'Autre client', nb: 1, type: 'subscriber', unsubscribed: false });
  const csv = [
    'NOABO|VOL1|VOL2|VOL3|VOL4|VOL5|VOL6|NOM_ABO|GPS|SECTEUR|QTE|TEL_FIXE|TEL_POR|CONSIGNE_LIV',
    '100||||||Fort-de-France|Nouveau nom|14.6,-61.07|SECT1|2|0596||Portail vert',
    '200|||12 rue Victor Hugo|||97200|Créé|14,61;-61,1|SECT.1|1||0696|',
    '300|||||||Sans secteur|1,1||1|||',
  ].join('\n');
  const r = await services.v1.imports.importCsv({ data: csv, clientName: 'FA' });
  assert.deepEqual([r.create, r.update, r.delete], [1, 1, 1]);
  const old = await store.get('Subscriber', 'old');
  assert.equal(old.name, 'Nouveau nom');
  assert.equal(old.unsubscribed, false);
  assert.equal(old.nb, 2);
  assert.equal(old.missionSubscribersId, 'M1');
  assert.equal(old.latitude, 14.6);
  const gone = await store.get('Subscriber', 'gone');
  assert.equal(gone.unsubscribed, true);
  assert.equal('missionSubscribersId' in gone, false);
  assert.equal((await store.get('Subscriber', 'other')).unsubscribed, false);
  const all = []; for await (const s of store.scanAll('Subscriber')) all.push(s);
  const created = all.find((s) => s.numabo === '200');
  assert.equal(created.missionSubscribersId, 'M1');
  assert.equal(created.phone1, '0696');
  assert.equal(all.some((s) => s.numabo === '300'), false); // pas de secteur : non créé (comportement historique)
  assert.equal(services.mailer.sent[0].to[0], 'rapport@exemple.fr');
  assert.match(services.mailer.sent[0].text, /NB CREATE : 1/);
});

test('import CSV : fichier invalide signalé dans le rapport, sans modification', async () => {
  const { store, services } = testServer();
  await store.put('Subscriber', { id: 'keep', owner: 'FA', numabo: '1', name: 'Gardé', nb: 1, type: 'subscriber', unsubscribed: false });
  const r = await services.v1.imports.importCsv({ data: 'A|B\n1|2', clientName: 'FA' });
  assert.match(r.report, /ERROR : CSV : colonnes attendues absentes/);
  assert.equal((await store.get('Subscriber', 'keep')).unsubscribed, false);
});

test('import Excel : points de vente créés, mis à jour et désinscrits', async () => {
  const { store, services } = testServer();
  await store.put('Mission', { id: 'M2', owner: 'FA', name: 'Nord', livreurID: 'l1' });
  await store.put('Subscriber', { id: 'pdv1', owner: 'FA', numabo: 'FDJ1', name: 'Tabac', nb: 1, type: 'subscriber', unsubscribed: false, address: 'x' });
  await store.put('Subscriber', { id: 'pdv9', owner: 'FA', numabo: 'FDJ9', name: 'Fermé', nb: 1, type: 'subscriber', unsubscribed: false });
  const sheet = XLSX.utils.aoa_to_sheet([
    ['N° PDV', 'nom PDV', 'Rue', 'Adresse', 'CP', 'Ville', 'Numéro', 'Mission', 'consigne liv', 'GPS'],
    [1, 'Tabac du port', '3', 'rue du Port', '97200', 'Fort-de-France', '0596000000', 'Nord', '', '14.6,-61.07'],
    [2, 'Presse', '8', 'rue Neuve', '97200', 'Fort-de-France', '', 'Nord', 'Fermé le lundi', '14.61,-61.08'],
  ]);
  const wb = XLSX.utils.book_new(); XLSX.utils.book_append_sheet(wb, sheet, 'PDV');
  const data = XLSX.write(wb, { type: 'base64', bookType: 'xlsx' });
  const r = await services.v1.imports.importExcel({ data, clientName: 'FA', nbColisDefaut: 3 });
  assert.deepEqual([r.create, r.update, r.delete], [1, 1, 1]);
  const pdv1 = await store.get('Subscriber', 'pdv1');
  assert.equal(pdv1.name, 'Tabac du port');
  assert.equal(pdv1.missionSubscribersId, 'M2');
  const all = []; for await (const s of store.scanAll('Subscriber')) all.push(s);
  const presse = all.find((s) => s.numabo === 'FDJ2');
  assert.equal(presse.nb, 3);
  assert.equal(presse.instructions, 'Fermé le lundi');
  assert.equal((await store.get('Subscriber', 'pdv9')).unsubscribed, true);
});

test('rattachement des abonnés à une mission', async () => {
  const { store, services } = testServer();
  for (const id of ['a', 'b', 'c']) await store.put('Subscriber', { id, owner: 'FA', name: id, nb: 1, type: 'subscriber', missionSubscribersId: id === 'a' ? 'M1' : undefined });
  const r = await services.v1.imports.updateMissionSubscribers({ missionId: 'M1', subscriberIds: ['b', 'c'], oldSubscriberIds: ['a', 'b'] });
  assert.deepEqual(r, { removed: 1, added: 1 });
  assert.equal('missionSubscribersId' in await store.get('Subscriber', 'a'), false);
  assert.equal((await store.get('Subscriber', 'c')).missionSubscribersId, 'M1');
});

test('planning des missions : jours, heure, fuseau et génération la veille', () => {
  const days = [true, false, true, false, false, false, true]; // lundi, mercredi, dimanche
  assert.deepEqual(missionCron({ startTime: 5.5, daysOfWeek: days, startTimeZone: 'America/Martinique' }), { expression: '30 5 * * 0,1,3', timezone: 'America/Martinique' });
  assert.deepEqual(missionCron({ startTime: 18, daysOfWeek: days, startTimeZone: 'Europe/Paris', generateDayBefore: true }).expression, '0 18 * * 0,2,6');
  assert.equal(missionCron({ startTime: 5, daysOfWeek: days }), null);
  assert.equal(missionCron({ startTime: 5, daysOfWeek: Array(7).fill(false), startTimeZone: 'UTC' }), null);
});

test('planificateur : missions programmées puis reprogrammées ou retirées à chaque modification', async () => {
  const { store, services } = testServer();
  const { createScheduler } = require('../src/scheduler');
  await store.put('Mission', { id: 'M1', owner: 'FA', name: 'A', livreurID: 'l1', startTime: 5, daysOfWeek: [true, true, true, true, true, false, false], startTimeZone: 'America/Martinique' });
  const sch = createScheduler(services);
  await sch.start();
  assert.ok(sch.missionJobs.has('M1'));
  await store.update('Mission', 'M1', { daysOfWeek: null }, {}, { removeNulls: true });
  await store.drain();
  assert.equal(sch.missionJobs.has('M1'), false);
  await store.update('Mission', 'M1', { daysOfWeek: [true, false, false, false, false, false, false] });
  await store.drain();
  assert.ok(sch.missionJobs.has('M1'));
  await store.delete('Mission', 'M1');
  await store.drain();
  assert.equal(sch.missionJobs.has('M1'), false);
  sch.stop();
});

test('bascule : réactions V1 et planning des missions désactivables', async () => {
  const { store, services } = testServer({ V1_TRIGGERS: 'false', MISSION_SCHEDULER: 'false' });
  await seedTournee(store);
  await store.delete('Tournee', 'T1');
  await store.drain();
  assert.ok(await store.get('Colis', 'C1')); // l'ancienne Lambda s'en charge encore
  const { createScheduler } = require('../src/scheduler');
  await store.put('Mission', { id: 'M1', owner: 'FA', name: 'A', livreurID: 'l1', startTime: 5, daysOfWeek: [true, true, true, true, true, false, false], startTimeZone: 'UTC' });
  const sch = createScheduler(services);
  await sch.start();
  assert.equal(sch.missionJobs.size, 0);
  sch.stop();
});

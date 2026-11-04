// Fonctions V1 portées depuis les anciennes Lambda Amplify, exposées en routes REST protégées :
//   GET  /v1/users                         liste des utilisateurs Cognito (admin)        ← listUsers (API REST)
//   POST /v1/missions/:id/tournees         génération d'une tournée                      ← createTournee
//   PUT  /v1/missions/:id/subscribers      rattachement des abonnés à la mission         ← updateMissionSubscribersId
//   POST /v1/imports/csv                   import CSV des abonnés                        ← importCSV
//   POST /v1/imports/excel                 import Excel des points de vente              ← importExcel
//   /v1/admin/users…                       gestion des utilisateurs Cognito du back-office V1 (cognitoAdmin.js)
// Les réactions aux écritures (anciens triggers) et la planification des missions sont dans triggers.js / scheduler.js.
const { createTriggers } = require('./triggers');
const { createTourneeGenerator } = require('./createTournee');
const { createImports } = require('./imports');
const { createUsers } = require('./users');
const { createRapport } = require('./rapport');
const { createCognitoAdmin } = require('./cognitoAdmin');

const STAFF = ['wabap', 'admin'];
const isStaff = (identity) => identity.groups.some((g) => STAFF.includes(g));
const clientOf = (identity) => identity.claims['custom:clientName'] || null;

function createV1({ store, mailer, config, log, fetchImpl, cognitoClient }) {
  const listeners = { mission: null };
  const triggers = createTriggers({ store, log, onMissionSchedule: (m, removedId) => listeners.mission?.(m, removedId) });
  const tournees = createTourneeGenerator({ store, config, log, fetchImpl });
  const imports = createImports({ store, mailer, config, log, fetchImpl });
  const users = createUsers({ config, client: cognitoClient });
  const admin = createCognitoAdmin({ config, client: cognitoClient });
  const rapport = createRapport({ store, mailer, config, users, log });

  // Accès : équipe Wabap, ou client propriétaire (attribut custom:clientName)
  const canActFor = (identity, owner) => isStaff(identity) || (owner && clientOf(identity) === owner);
  async function missionFor(req) {
    const mission = await store.get('Mission', req.params.id);
    if (!mission) throw Object.assign(new Error('Mission introuvable'), { status: 404 });
    if (!canActFor(req.identity, mission.owner)) throw Object.assign(new Error('Accès refusé'), { status: 403 });
    return mission;
  }
  const handler = (fn) => async (req, res) => {
    try { res.json(await fn(req)); } catch (e) {
      if (!e.status) log.error(`[v1] ${req.method} ${req.path}`, e);
      res.status(e.status || 500).json({ error: e.status ? e.message : 'Erreur serveur' });
    }
  };

  function routes(router) {
    router.get('/users', handler(async (req) => {
      if (!req.identity.groups.includes('admin') && !req.identity.groups.includes('wabap')) throw Object.assign(new Error('Accès réservé aux administrateurs'), { status: 403 });
      // Administrateur d'un client : uniquement les comptes de ce client
      const all = await users.list();
      return clientOf(req.identity) ? all.filter((u) => u.client_name === clientOf(req.identity)) : all;
    }));
    router.post('/missions/:id/tournees', handler(async (req) => {
      await missionFor(req);
      return tournees.generate({ missionId: req.params.id, createForTomorrow: req.body?.createForTomorrow === true });
    }));
    router.put('/missions/:id/subscribers', handler(async (req) => {
      await missionFor(req);
      return imports.updateMissionSubscribers({ missionId: req.params.id, subscriberIds: req.body?.subscriberIds, oldSubscriberIds: req.body?.oldSubscriberIds });
    }));
    router.post('/imports/csv', handler(async (req) => {
      if (!canActFor(req.identity, req.body?.clientName)) throw Object.assign(new Error('Accès refusé'), { status: 403 });
      return imports.importCsv({ data: req.body.data, clientName: req.body.clientName });
    }));
    router.get('/admin/users', handler((req) => admin.list(req.identity)));
    router.get('/admin/users/by-sub/:sub', handler((req) => admin.bySub(req.identity, req.params.sub)));
    router.get('/admin/users/:username/groups', handler((req) => admin.groups(req.identity, req.params.username)));
    router.post('/admin/users', handler((req) => admin.create(req.identity, req.body || {})));
    router.put('/admin/users/:username', handler((req) => admin.update(req.identity, req.params.username, req.body || {})));
    router.delete('/admin/users/:username', handler((req) => admin.remove(req.identity, req.params.username)));
    router.post('/imports/excel', handler(async (req) => {
      if (!canActFor(req.identity, req.body?.clientName)) throw Object.assign(new Error('Accès refusé'), { status: 403 });
      return imports.importExcel({ data: req.body.data, clientName: req.body.clientName, nbColisDefaut: req.body.nbColisDefaut });
    }));
  }

  return {
    routes,
    triggers,
    tournees,
    imports,
    users,
    admin,
    rapport,
    // Le planificateur s'abonne aux changements de mission
    onMissionChange(fn) { listeners.mission = fn; },
  };
}

module.exports = { createV1 };

// Tâches planifiées (remplacent les règles EventBridge) :
//  - génération automatique des tournées V1 selon le planning de chaque mission (jours, heure, fuseau) ;
//  - envoi automatique des étiquettes aux clients B2B (toutes les 30 minutes par défaut) ;
//  - imports SFTP planifiés des abonnés (SFTP_IMPORTS).
// Une seule instance du serveur doit exécuter ces tâches (SCHEDULER_ENABLED=false sur les autres).
const cron = require('node-cron');

// Planning d'une mission → expression cron (minutes heure * * jours) dans le fuseau de la mission.
// daysOfWeek : [lundi … dimanche] ; generateDayBefore : la tournée est générée la veille.
function missionCron(m) {
  if (m.startTime === undefined || m.startTime === null || !Array.isArray(m.daysOfWeek) || !m.startTimeZone) return null;
  const hour = Math.trunc(m.startTime);
  const minutes = Math.round((m.startTime - hour) * 60);
  const days = m.daysOfWeek
    .map((on, i) => (on ? (m.generateDayBefore ? i : (i + 1) % 7) : null)) // cron : 0 = dimanche, 1 = lundi
    .filter((d) => d !== null);
  if (!days.length) return null;
  return { expression: `${minutes} ${hour} * * ${[...new Set(days)].sort((a, b) => a - b).join(',')}`, timezone: m.startTimeZone };
}

function createScheduler(services) {
  const { store, v1, delivery, config, log } = services;
  const jobs = [];
  const missionJobs = new Map();

  function scheduleMission(m, removedId) {
    const id = m?.id || removedId;
    missionJobs.get(id)?.stop();
    missionJobs.delete(id);
    if (!m) return;
    const c = missionCron(m);
    if (!c || !cron.validate(c.expression)) return;
    const job = cron.schedule(c.expression, () => {
      v1.tournees.generate({ missionId: m.id, createForTomorrow: !!m.generateDayBefore })
        .catch((e) => log.error(`[planning] mission ${m.id}`, e.message));
    }, { timezone: c.timezone });
    missionJobs.set(id, job);
  }

  return {
    missionJobs,
    async start() {
      let n = 0;
      if (config.missionScheduler !== false) {
        for await (const m of store.scanAll('Mission')) { scheduleMission(m); if (missionJobs.has(m.id)) n++; }
        v1.onMissionChange(scheduleMission);
      }
      jobs.push(cron.schedule(config.labelsCron, () => delivery.labels.sendDue().catch((e) => log.error('[étiquettes]', e))));
      for (const imp of config.sftpImports) {
        jobs.push(cron.schedule(imp.cron, () => {
          v1.imports.importCsv({ clientName: imp.clientName, ftp: imp }).catch((e) => log.error('[import SFTP]', e));
        }, { timezone: imp.timezone || 'UTC' }));
      }
      log.log(`Tâches planifiées : ${config.missionScheduler !== false ? `${n} mission(s)` : 'missions désactivées'}, étiquettes (${config.labelsCron}), ${config.sftpImports.length} import(s) SFTP`);
    },
    stop() {
      for (const j of [...jobs, ...missionJobs.values()]) j.stop();
    },
  };
}

module.exports = { createScheduler, missionCron };

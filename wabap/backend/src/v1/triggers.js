// Réactions aux écritures sur les modèles V1 (anciennes fonctions triggerColisStatus, triggerTournee,
// triggerMission branchées sur les flux DynamoDB). Comportement identique, écritures via le stockage
// du serveur (elles déclenchent à leur tour les réactions, comme le faisait le flux).
const crypto = require('crypto');

function createTriggers({ store, log, onMissionSchedule }) {
  // ---------- ColisStatus : dernier statut du colis et passage du colis suivant « en cours » ----------
  async function onColisStatus({ eventName, newImage: s }) {
    if (eventName !== 'INSERT') return;
    if (!s?.colisLogsId || !s.status) return;

    const colis = await store.get('Colis', s.colisLogsId);
    if (!colis) return; // statut créé avant son colis (génération de tournée) : rien à faire
    const last = colis.lastStatus;
    const lastStatus = last ? last.status : null;
    const tourneeId = colis.tourneeColisId;

    // Ordre : seul un statut plus récent que le dernier connu est pris en compte (rejeu tardif, hors ligne…)
    const newTime = Date.parse(s.createdAt);
    const lastTime = last && last.createdAt ? Date.parse(last.createdAt) : NaN;
    const isNewer = Number.isNaN(lastTime) || (!Number.isNaN(newTime) && newTime > lastTime);
    if (!isNewer) {
      log.log(`[colis] statut ancien ignoré ${s.createdAt} <= ${last.createdAt} (colis ${s.colisLogsId})`);
      return;
    }

    if (s.status !== 'IN_PROGRESS' || lastStatus !== 'COMPLETED') {
      await store.update('Colis', s.colisLogsId, {
        colisLastStatusId: s.id,
        lastStatus: { id: s.id, createdAt: s.createdAt, status: s.status, updatedAt: s.updatedAt },
      });
    }

    // Colis livré ou en anomalie : le premier colis en attente de la tournée passe « en cours »
    if (s.status === 'COMPLETED' || s.status === 'ISSUE') {
      const list = await store.query('Colis', 'byTourneeOrderPosition', 'tourneeColisId', tourneeId, { limit: 300, desc: true });
      let firstPending = null;
      let alreadyInProgress = false;
      for (const c of list) {
        if (!c.lastStatus) continue;
        if (c.lastStatus.status === 'PENDING') firstPending = c; // parcours décroissant : le dernier trouvé est le premier de la tournée
        if (c.lastStatus.status === 'IN_PROGRESS') alreadyInProgress = true;
      }
      if (firstPending && !alreadyInProgress) {
        const at = new Date().toISOString();
        await store.put('ColisStatus', {
          __typename: 'ColisStatus', id: crypto.randomUUID(), createdAt: at, updatedAt: at,
          colisLogsId: firstPending.id, status: 'IN_PROGRESS', owner: s.owner,
        });
      }
    }
  }

  // ---------- Tournee supprimée : suppression de ses colis et de leurs statuts ----------
  async function onTournee({ eventName, oldImage: t }) {
    if (eventName !== 'REMOVE') return;
    let nColis = 0, nStatus = 0;
    for (const colis of await store.query('Colis', 'gsi-Tournee.colis', 'tourneeColisId', t.id, { limit: 100000 })) {
      await store.delete('Colis', colis.id);
      nColis++;
      for (const st of await store.query('ColisStatus', 'gsi-Colis.logs', 'colisLogsId', colis.id, { limit: 100000 })) {
        await store.delete('ColisStatus', st.id);
        nStatus++;
      }
    }
    log.log(`[tournée ${t.id}] supprimée : ${nColis} colis, ${nStatus} statuts`);
  }

  // ---------- Mission : planification de la génération des tournées, nettoyage à la suppression ----------
  async function onMission({ eventName, newImage: m, oldImage: old }) {
    if (eventName === 'INSERT' || eventName === 'MODIFY') {
      if (!m?.livreurID || !m.id) return;
      onMissionSchedule?.(m);
      return;
    }
    if (eventName !== 'REMOVE') return;
    onMissionSchedule?.(null, old.id);
    for (const sub of await store.query('Subscriber', 'gsi-Mission.subscribers', 'missionSubscribersId', old.id, { limit: 100000 })) {
      await store.update('Subscriber', sub.id, { missionSubscribersId: null }, {}, { removeNulls: true }).catch((e) => log.error('[mission] abonné', e));
    }
    for (const ins of await store.query('Inscription', 'gsi-Mission.inscriptions', 'missionInscriptionsId', old.id, { limit: 100000 })) {
      await store.delete('Inscription', ins.id);
    }
    for (const t of await store.query('Tournee', 'gsi-Mission.tournee', 'missionTourneeId', old.id, { limit: 100000 })) {
      await store.delete('Tournee', t.id);
    }
    log.log(`[mission ${old.id}] supprimée : abonnés détachés, inscriptions et tournées supprimées`);
  }

  store.on('ColisStatus', onColisStatus);
  store.on('Tournee', onTournee);
  store.on('Mission', onMission);
  return { onColisStatus, onTournee, onMission };
}

module.exports = { createTriggers };

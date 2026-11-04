// Rapport de fin de tournée V1 (mutation invokeLambdaRapportTournee appelée par l'app livreur quand
// le contrôle du ramassage est activé). La fonction Lambda d'origine ne figure pas dans le dépôt :
// ce rapport récapitule la tournée (colis livrés, en anomalie, non traités, messages du livreur)
// et l'envoie aux destinataires configurés (TOURNEE_REPORT_EMAILS) et aux utilisateurs du client.
const STATUS_LABELS = { COMPLETED: 'Livré', ISSUE: 'Anomalie', IN_PROGRESS: 'En cours', PENDING: 'Non traité' };

function createRapport({ store, mailer, config, users, log }) {
  async function generate({ tourneeId, message }, identity) {
    const tournee = await store.get('Tournee', tourneeId);
    if (!tournee) return { statusCode: 404, message: 'Tournée introuvable' };
    const staff = identity.groups.some((g) => ['wabap', 'admin'].includes(g));
    const mine = tournee.livreurID === identity.sub || tournee.owner === identity.claims['custom:clientName'];
    if (!staff && !mine) return { statusCode: 403, message: 'Accès refusé' };

    const colis = (await store.query('Colis', 'byTourneeOrderPosition', 'tourneeColisId', tourneeId, { limit: 100000, desc: false }))
      .sort((a, b) => a.position - b.position);
    const counts = {};
    const lines = [];
    for (const c of colis) {
      const st = c.lastStatus?.status || 'PENDING';
      counts[st] = (counts[st] || 0) + 1;
      if (st !== 'COMPLETED') {
        const logs = await store.query('ColisStatus', 'byColisOrderDate', 'colisLogsId', c.id, { limit: 50, desc: true });
        const note = logs.find((l) => l.message)?.message;
        lines.push(`  ${c.position}. ${c.subscriberName} — ${c.address} : ${STATUS_LABELS[st] || st}${note ? ` (${note})` : ''}`);
      }
    }
    const text = [
      `Rapport de la tournée « ${tournee.name} »`,
      '',
      `Colis : ${colis.length}`,
      ...Object.entries(counts).map(([k, n]) => `  ${STATUS_LABELS[k] || k} : ${n}`),
      '',
      lines.length ? 'Colis non livrés :' : 'Tous les colis ont été livrés.',
      ...lines,
      ...(message ? ['', `Message du livreur : ${message}`] : []),
    ].join('\n');

    const to = new Set(config.tourneeReportEmails || []);
    try {
      for (const u of await users.list()) if (u.client_name === tournee.owner && u.email) to.add(u.email);
    } catch (e) { log.warn?.(`[rapport] destinataires Cognito indisponibles : ${e.message}`); }
    if (!to.size) return { statusCode: 200, message: 'Rapport généré (aucun destinataire configuré)' };
    await mailer.send({ to: [...to], from: config.reportSender, subject: `Rapport de tournée : ${tournee.name}`, text });
    return { statusCode: 200, message: `Rapport envoyé à ${to.size} destinataire(s)` };
  }
  return { generate };
}

module.exports = { createRapport };

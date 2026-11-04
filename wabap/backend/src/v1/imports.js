// Import des abonnés V1 (anciennes fonctions importCSV et importExcel) : création, mise à jour et
// désinscription des abonnés d'un client, rattachement à la mission de leur secteur, rapport par e-mail.
const crypto = require('crypto');
const os = require('os');
const path = require('path');
const fs = require('fs');
const moment = require('moment');
const { parse: parseCsv } = require('csv-parse/sync');
const XLSX = require('xlsx');

const CSV_COLUMNS = ['NOABO', 'VOL1', 'VOL2', 'VOL3', 'VOL4', 'VOL5', 'VOL6', 'NOM_ABO', 'GPS'];

const has = (o, k) => o !== null && typeof o === 'object' && k in o && o[k] !== null && o[k] !== undefined && o[k] !== '';
const get = (o, k) => (has(o, k) ? o[k] : null);
const cleanSecteur = (s) => s?.toLowerCase().replace(/\./g, '') ?? '';
const coord = (s) => {
  const v = String(s ?? '').replace(/[^-.0-9]/g, '');
  return v === '' ? null : Number(v);
};
const int = (v) => (v === null || v === undefined || v === '' ? null : Number.parseInt(v, 10));

// Rapport d'import (texte envoyé par e-mail)
function createReport(title) {
  const lines = [];
  const counts = { update: 0, delete: 0, create: 0 };
  const add = (msg) => lines.push(msg);
  add(`${title} START : ${new Date().toISOString()}`);
  return {
    add,
    update: (s) => { if (s) { counts.update++; add(` >> UPDATE SUBSCRIBER : ${JSON.stringify(s)}`); } },
    delete: (s) => { if (s) { counts.delete++; add(` >> DELETE SUBSCRIBER : ${JSON.stringify(s)}`); } },
    create: (s) => { if (s) { counts.create++; add(` >> CREATE SUBSCRIBER : ${JSON.stringify(s)}`); } },
    finish() {
      add(' ---------------------------- ');
      add(` --- NB UPDATE : ${counts.update}`);
      add(` --- NB DELETE : ${counts.delete}`);
      add(` --- NB CREATE : ${counts.create}`);
      add(`${title} END : ${new Date().toISOString()}`);
      return { text: lines.join('\n'), counts: { ...counts } };
    },
  };
}

function createImports({ store, mailer, config, log, fetchImpl = fetch }) {
  async function geocode(address) {
    if (!address || !config.googleMapsKey) return null;
    const res = await fetchImpl(`https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${config.googleMapsKey}`);
    const data = await res.json();
    return data.status === 'OK' ? data.results[0].geometry.location : null;
  }

  // Missions du client : nom de secteur normalisé → id
  async function missionsOf(clientName) {
    const map = {};
    for await (const m of store.scanAll('Mission')) if (m.owner === clientName) map[cleanSecteur(m.name)] = m.id;
    return map;
  }

  async function subscribersOf(clientName) {
    const subs = [];
    for await (const s of store.scanAll('Subscriber')) if (s.owner === clientName) subs.push(s);
    return subs;
  }

  // Mise à jour partielle : null = attribut supprimé
  async function saveUpdate(sub) {
    const { id, ...patch } = sub;
    if (Object.keys(patch).length) await store.update('Subscriber', id, patch, {}, { removeNulls: true });
  }

  async function sendReport(subject, text, error = false) {
    const to = error ? config.importErrorEmails : config.importReportEmails;
    if (!to.length) { log.log(`[import] rapport non envoyé (destinataires non configurés) : ${subject}`); return; }
    try {
      await mailer.send({ to, from: config.reportSender, subject, text });
    } catch (e) { log.error('[import] envoi du rapport', e); }
  }

  const unsubscribed = (s) => ({ id: s.id, unsubscribed: true, missionSubscribersId: null });

  // ---------- CSV (séparateur « | ») : données envoyées par le back-office ou fichier SFTP ----------
  async function readCsv({ data, ftp }, report) {
    let content = data;
    if (!content && ftp) {
      const filename = moment().format(ftp.filename);
      report.add(`IMPORT CSV FROM FTP : ${filename}`);
      content = await downloadSftp(ftp, filename);
    } else if (content) {
      report.add(`IMPORT CSV FROM DATA size=${content.length}`);
    } else {
      throw new Error('Aucune donnée ni information SFTP');
    }
    const rows = parseCsv(content, { columns: true, delimiter: '|', bom: true, relax_quotes: true, relax_column_count: true, skip_empty_lines: true });
    report.add(`CSV FILE LINE : ${rows.length}`);
    if (!rows.length || !CSV_COLUMNS.every((c) => Object.prototype.hasOwnProperty.call(rows[0], c))) throw new Error('CSV : colonnes attendues absentes');
    return rows;
  }

  async function downloadSftp(ftp, filename) {
    const Client = require('ssh2-sftp-client');
    const tmp = path.join(os.tmpdir(), `abonnes-${crypto.randomUUID()}.csv`);
    let lastError;
    for (let attempt = 1; attempt <= 3; attempt++) {
      const client = new Client();
      try {
        await client.connect({ host: ftp.host, port: ftp.port || 22, username: ftp.username, password: ftp.password });
        await client.get(filename, tmp);
        return fs.readFileSync(tmp, 'utf8');
      } catch (e) {
        lastError = e;
        if (/No such file/.test(e.message)) throw e; // connexion correcte mais fichier absent
        if (attempt < 3) await new Promise((r) => setTimeout(r, 30_000));
      } finally {
        await client.end().catch(() => {});
        fs.rmSync(tmp, { force: true });
      }
    }
    await sendReport('[WABAP] !! ERREUR !! import CSV', "ERREUR lors de l'importation du CSV. Impossible de se connecter au serveur SFTP après 3 tentatives.", true);
    throw lastError;
  }

  const csvName = (s) => get(s, 'NOM_ABO') ?? get(s, 'VOL1') ?? get(s, 'VOL2');
  const csvAddress = (s) => ['VOL3', 'VOL4', 'VOL5', 'VOL6'].map((k) => get(s, k)).filter(Boolean).join(' ').trim() || null;
  const csvPhone1 = (s) => get(s, 'TEL_FIXE') ?? get(s, 'TEL_POR');
  const csvPhone2 = (s) => (has(s, 'TEL_FIXE') && has(s, 'TEL_POR') ? s.TEL_POR : null);

  async function importCsv({ data, ftp, clientName }) {
    if (!clientName) throw Object.assign(new Error('clientName requis'), { status: 400 });
    const report = createReport('IMPORT CSV');
    try {
      const rows = await readCsv({ data, ftp }, report);
      const missions = await missionsOf(clientName);
      const remaining = [...rows];
      for (const db of await subscribersOf(clientName)) {
        const i = remaining.findIndex((s) => s.NOABO !== undefined && s.NOABO === db.numabo);
        const row = i !== -1 ? remaining.splice(i, 1)[0] : null;
        if (row) {
          const upd = await csvUpdate(row, db, missions);
          if (upd) { report.update(upd); await saveUpdate(upd); }
        } else if (db.unsubscribed === false || db.missionSubscribersId !== undefined) {
          const upd = unsubscribed(db);
          report.delete(upd);
          await saveUpdate(upd);
        }
      }
      for (const row of remaining) {
        const sub = await csvNew(row, missions, clientName);
        if (sub && sub.secteur !== undefined) { // comportement historique : pas de création sans secteur
          report.create(sub);
          await store.put('Subscriber', sub);
        }
      }
    } catch (e) {
      report.add(`ERROR : ${e.message}`);
      log.error('[import CSV]', e.message);
    }
    const { text, counts } = report.finish();
    await sendReport(`RAPPORT import CSV : ${new Date().toISOString()}`, text);
    return { ...counts, report: text };
  }

  async function csvNew(row, missions, clientName) {
    const numabo = get(row, 'NOABO');
    const name = csvName(row);
    if (numabo === null || name === null) return null;
    const at = new Date().toISOString();
    const sub = { __typename: 'Subscriber', id: crypto.randomUUID(), createdAt: at, updatedAt: at, nb: 1, type: 'subscriber', name, numabo, unsubscribed: false, owner: clientName };
    const address = csvAddress(row);
    if (address !== null) sub.address = address;
    if (csvPhone1(row) !== null) sub.phone1 = csvPhone1(row);
    if (csvPhone2(row) !== null) sub.phone2 = csvPhone2(row);
    const secteur = get(row, 'SECTEUR');
    if (secteur !== null) {
      sub.secteur = secteur;
      if (missions[cleanSecteur(secteur)]) sub.missionSubscribersId = missions[cleanSecteur(secteur)];
    }
    if (get(row, 'CONSIGNE_LIV') !== null) sub.instructions = row.CONSIGNE_LIV;
    if (get(row, 'QTE') !== null) sub.nb = int(row.QTE);
    const gps = get(row, 'GPS');
    if (gps !== null) {
      const parts = gps.split(',');
      if (parts.length === 2) { sub.latitude = coord(parts[0]); sub.longitude = coord(parts[1]); }
    } else {
      const g = await geocode(address);
      if (g) { sub.latitude = g.lat; sub.longitude = g.lng; }
    }
    return sub;
  }

  async function csvUpdate(row, db, missions) {
    const u = {};
    const name = csvName(row);
    if (name != db.name) u.name = name; // eslint-disable-line eqeqeq
    const address = csvAddress(row);
    if (address != db.address) { // eslint-disable-line eqeqeq
      u.address = address;
      if (get(row, 'GPS') === null) {
        const g = await geocode(address);
        if (g) { u.latitude = g.lat; u.longitude = g.lng; }
      }
    }
    if (csvPhone1(row) != db.phone1) u.phone1 = csvPhone1(row); // eslint-disable-line eqeqeq
    if (csvPhone2(row) != db.phone2) u.phone2 = csvPhone2(row); // eslint-disable-line eqeqeq
    const secteur = get(row, 'SECTEUR');
    if (secteur != db.secteur) u.secteur = secteur; // eslint-disable-line eqeqeq
    // Sans mission, ou dans la mission de son secteur dont le secteur change : rattachement au nouveau secteur
    if (db.missionSubscribersId === undefined || (db.missionSubscribersId === missions[cleanSecteur(db.secteur)] && u.secteur !== undefined)) {
      if (missions[cleanSecteur(secteur)]) u.missionSubscribersId = missions[cleanSecteur(secteur)];
    }
    const instructions = get(row, 'CONSIGNE_LIV');
    if (instructions != db.instructions) u.instructions = instructions; // eslint-disable-line eqeqeq
    const nb = int(get(row, 'QTE'));
    if (nb !== null && nb !== db.nb) u.nb = nb;
    const gps = get(row, 'GPS');
    if (gps) {
      const parts = gps.split(',');
      if (parts.length === 2) {
        const lat = coord(parts[0]), lng = coord(parts[1]);
        if (lat !== db.latitude) u.latitude = lat;
        if (lng !== db.longitude) u.longitude = lng;
      }
    }
    if (db.unsubscribed === true) u.unsubscribed = false;
    if (!Object.keys(u).length) return null;
    return { id: db.id, ...u, updatedAt: new Date().toISOString() };
  }

  // ---------- Excel (points de vente) : fichier envoyé en base64 par le back-office ----------
  function readExcel(base64) {
    const wb = XLSX.read(Buffer.from(base64, 'base64'), { type: 'buffer' });
    const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { header: 1 });
    const headers = rows[0] || [];
    return rows.slice(1).filter((r) => r.length).map((r) => Object.fromEntries(headers.map((h, i) => [h, r[i]])));
  }
  const xNumabo = (x) => `FDJ${x['N° PDV']}`;
  const xAddress = (x) => `${x.Rue} ${x.Adresse}, ${x.CP} ${x.Ville}`;

  async function importExcel({ data, clientName, nbColisDefaut }) {
    if (!clientName) throw Object.assign(new Error('clientName requis'), { status: 400 });
    if (!data) throw Object.assign(new Error('Fichier Excel absent'), { status: 400 });
    const report = createReport('IMPORT EXCEL');
    try {
      const rows = readExcel(data);
      const missions = await missionsOf(clientName);
      const existing = await subscribersOf(clientName);
      for (const db of existing) {
        const row = rows.find((x) => xNumabo(x) === db.numabo);
        if (row) {
          const upd = await excelUpdate(row, db, missions);
          if (upd) { report.update(upd); await saveUpdate(upd); }
        } else if (!db.unsubscribed || db.missionSubscribersId) {
          const upd = unsubscribed(db);
          report.delete(upd);
          await saveUpdate(upd);
        }
      }
      const known = new Set(existing.map((s) => s.numabo));
      for (const row of rows) {
        if (known.has(xNumabo(row))) continue;
        known.add(xNumabo(row));
        const sub = await excelNew(row, missions, clientName, nbColisDefaut);
        report.create(sub);
        await store.put('Subscriber', sub);
      }
    } catch (e) {
      report.add(`ERROR: ${e.message}`);
      log.error('[import Excel]', e.message);
    }
    const { text, counts } = report.finish();
    await sendReport(`RAPPORT import Excel : ${new Date().toISOString()}`, text);
    return { ...counts, report: text };
  }

  async function excelNew(x, missions, clientName, nbColisDefaut) {
    const at = new Date().toISOString();
    const sub = {
      __typename: 'Subscriber', id: crypto.randomUUID(), createdAt: at, updatedAt: at,
      nb: int(nbColisDefaut) || 1, type: 'subscriber', name: x['nom PDV'], numabo: xNumabo(x), unsubscribed: false, owner: clientName,
      address: xAddress(x),
    };
    if (x['Numéro']) sub.phone1 = String(x['Numéro']);
    if (x.Mission) {
      sub.secteur = x.Mission;
      if (missions[cleanSecteur(x.Mission)]) sub.missionSubscribersId = missions[cleanSecteur(x.Mission)];
    }
    if (x['consigne liv']) sub.instructions = x['consigne liv'];
    if (x.GPS) {
      const [lat, lng] = String(x.GPS).split(',');
      sub.latitude = coord(lat); sub.longitude = coord(lng);
    } else {
      const g = await geocode(sub.address);
      if (g) { sub.latitude = g.lat; sub.longitude = g.lng; }
    }
    return sub;
  }

  async function excelUpdate(x, db, missions) {
    const u = {};
    if (x['nom PDV'] !== db.name) u.name = x['nom PDV'];
    const address = xAddress(x);
    if (address !== db.address) {
      u.address = address;
      if (!x.GPS) {
        const g = await geocode(address);
        if (g) { u.latitude = g.lat; u.longitude = g.lng; }
      }
    }
    const phone1 = x['Numéro'] === undefined ? undefined : String(x['Numéro']);
    if (phone1 !== db.phone1) u.phone1 = phone1 ?? null;
    if (x.Mission !== db.secteur) {
      u.secteur = x.Mission ?? null;
      const idMission = missions[cleanSecteur(x.Mission)];
      if (idMission !== db.missionSubscribersId) u.missionSubscribersId = idMission ?? null;
    }
    if (x['consigne liv'] !== db.instructions) u.instructions = x['consigne liv'] ?? null;
    if (x.GPS) {
      const [lat, lng] = String(x.GPS).split(',');
      if (coord(lat) !== db.latitude) u.latitude = coord(lat);
      if (coord(lng) !== db.longitude) u.longitude = coord(lng);
    }
    if (db.unsubscribed === true) u.unsubscribed = false;
    if (!Object.keys(u).length) return null;
    return { id: db.id, ...u, updatedAt: new Date().toISOString() };
  }

  // ---------- Rattachement des abonnés à une mission (ancienne fonction updateMissionSubscribersId) ----------
  async function updateMissionSubscribers({ missionId, subscriberIds, oldSubscriberIds }) {
    // Liste vide acceptée : la mission n'a plus d'abonnés (l'ancienne fonction ignorait ce cas)
    if (!missionId || !Array.isArray(subscriberIds)) throw Object.assign(new Error('missionId et subscriberIds requis'), { status: 400 });
    const old = Array.isArray(oldSubscriberIds) ? oldSubscriberIds : [];
    const removed = old.filter((id) => !subscriberIds.includes(id));
    const added = old.length ? subscriberIds.filter((id) => !old.includes(id)) : subscriberIds;
    await Promise.all([
      ...removed.map((id) => store.update('Subscriber', id, { missionSubscribersId: null }, {}, { removeNulls: true })),
      ...added.map((id) => store.update('Subscriber', id, { missionSubscribersId: missionId })),
    ]);
    return { removed: removed.length, added: added.length };
  }

  return { importCsv, importExcel, updateMissionSubscribers };
}

module.exports = { createImports, createReport };

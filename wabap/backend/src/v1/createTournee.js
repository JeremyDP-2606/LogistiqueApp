// Génération d'une tournée V1 à partir d'une mission (ancienne fonction createTournee) :
// ordre optimal des abonnés par RouteXL, tracés Google Directions, création des colis et statuts.
const crypto = require('crypto');
const moment = require('moment-timezone');
require('moment/locale/fr');

function createTourneeGenerator({ store, config, log, fetchImpl = fetch }) {
  async function routeXL(mission, subscribers) {
    if (!config.routexlAuth) throw new Error('ROUTEXL_AUTH manquant');
    if (!subscribers.length) throw new Error('Aucun colis');
    if (mission.startLatitude === undefined || mission.startLongitude === undefined) throw new Error('Mission sans position de départ');
    const locations = [
      { address: 'start', lat: mission.startLatitude, lng: mission.startLongitude },
      ...subscribers.map((s) => ({ address: s.id, lat: s.latitude, lng: s.longitude })),
      // l'arrivée est obligatoire pour RouteXL : retirée ensuite
      { address: 'end', lat: mission.startLatitude, lng: mission.startLongitude },
    ];
    const res = await fetchImpl('https://api.routexl.com/tour/', {
      method: 'POST',
      headers: { Authorization: `Basic ${config.routexlAuth}`, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `locations=${JSON.stringify(locations)}`,
    });
    if (!res.ok) throw new Error(`RouteXL ${res.status}`);
    return res.json();
  }

  async function directions(from, to) {
    if (!config.googleMapsKey) throw new Error('GOOGLE_MAPS_API_KEY manquant');
    const res = await fetchImpl(`https://maps.googleapis.com/maps/api/directions/json?origin=${from.lat},${from.lng}&destination=${to.lat},${to.lng}&mode=driving&key=${config.googleMapsKey}`);
    if (!res.ok) throw new Error(`Google Directions ${res.status}`);
    return res.json();
  }

  async function generate({ missionId, createForTomorrow = false }) {
    if (!missionId) throw Object.assign(new Error('missionId requis'), { status: 400 });
    const mission = await store.get('Mission', missionId);
    if (!mission) throw Object.assign(new Error('Mission introuvable'), { status: 404 });

    const date = moment().tz(mission.startTimeZone || 'America/Martinique').locale('fr');
    if (createForTomorrow) date.add(1, 'days');
    const at = () => new Date().toISOString();
    const tournee = {
      __typename: 'Tournee',
      id: crypto.randomUUID(),
      name: `${mission.name} du ${date.format('dddd D MMMM')}`,
      status: 'PENDING',
      startName: mission.startName,
      startLongitude: mission.startLongitude,
      startLatitude: mission.startLatitude,
      livreurID: mission.livreurID,
      missionTourneeId: missionId,
      createdAt: at(),
      updatedAt: at(),
      owner: mission.owner,
    };
    await store.put('Tournee', tournee);

    const subscribers = (await store.query('Subscriber', 'gsi-Mission.subscribers', 'missionSubscribersId', missionId, { limit: 100000 }))
      .filter((s) => s.unsubscribed === false && s.latitude !== undefined && s.latitude !== null && s.longitude !== undefined && s.longitude !== null);
    const route = await routeXL(mission, subscribers);
    const order = {};
    Object.keys(route.route).forEach((k, i) => { order[route.route[k].name] = i; });
    subscribers.sort((a, b) => order[a.id] - order[b.id]);

    let distanceTotal = 0, durationTotal = 0, nbColis = 0;
    const colisList = [];
    let previous = { lat: mission.startLatitude, lng: mission.startLongitude };
    for (const [index, sub] of subscribers.entries()) {
      try {
        for (let i = 0; i < (Number(sub.nb) || 1); i++) {
          const leg = await directions(previous, { lat: sub.latitude, lng: sub.longitude });
          const r = leg.routes?.[0];
          const polyline = i === 0 ? r?.overview_polyline?.points || '' : '';
          const distance = i === 0 ? r?.legs?.[0]?.distance?.value || 0 : 0;
          const duration = i === 0 ? r?.legs?.[0]?.duration?.value || 0 : 0;
          distanceTotal += distance;
          durationTotal += duration + 60; // 1 minute par colis
          const colisId = crypto.randomUUID();
          const status = { __typename: 'ColisStatus', id: crypto.randomUUID(), createdAt: at(), updatedAt: at(), colisLogsId: colisId, status: 'PENDING', owner: mission.owner };
          await store.put('ColisStatus', status);
          const colis = {
            __typename: 'Colis', id: colisId, createdAt: at(), updatedAt: at(),
            position: index + 1, subscriberColisId: sub.id, tourneeColisId: tournee.id,
            polyline, distance, duration,
            address: sub.address, longitude: sub.longitude, latitude: sub.latitude, subscriberName: sub.name,
            owner: mission.owner, lastStatus: status, colisLastStatusId: status.id,
          };
          await store.put('Colis', colis);
          colisList.push(colis);
          previous = { lat: sub.latitude, lng: sub.longitude };
          nbColis++;
        }
      } catch (e) {
        log.error(`[tournée] colis de l'abonné ${sub.id} non créé :`, e.message);
      }
    }
    const updated = await store.update('Tournee', tournee.id, { distance: distanceTotal, duree: durationTotal, nbColis });
    log.log(`[tournée] ${tournee.name} : ${nbColis} colis, ${Math.round(distanceTotal / 1000)} km`);
    return { ...updated, colis: { items: colisList } };
  }

  return { generate };
}

module.exports = { createTourneeGenerator };

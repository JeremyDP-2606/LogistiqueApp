// Tournées et exécution des points (spec §3, §5, §6, §7.2, §11 ter).
const crypto = require('crypto');
const { plan, appendDetourKm } = require('./planning');
const { distanceMeters, round2 } = require('./geo');
const P = require('./proofs');
const { decodeCode, shortId, customerTag } = require('./labels');
const { UserError, isStaff, customerIdFor } = require('./orders');

const SAME_PLACE_METERS = 30;
const DEFAULT_CONFIG = { distanceAlertMeters: 200, maxAddDetourKm: 3, failurePhotoRequired: true };

function createTours(ctx, orders) {
  const { store, labelSecret } = ctx;
  const cfg = { ...DEFAULT_CONFIG, ...(ctx.config || {}) };
  const iso = () => (ctx.now ? ctx.now() : new Date()).toISOString();

  const getTour = async (id) => {
    const t = await store.get('Tour', id);
    if (!t) throw new UserError('Tournée introuvable');
    return t;
  };
  const stopsOf = async (tourId) => (await store.query('Stop', 'byTour', 'tourId', tourId)).sort((a, b) => a.sequence - b.sequence);
  const requireStaff = (identity) => { if (!isStaff(identity)) throw new UserError('Réservé aux équipes Wabap'); };

  // ---------- Création ----------
  async function createTour(identity, { name, date, slot = 'DAY', startTime, start, end, courierId, dedicatedCustomerId }) {
    requireStaff(identity);
    if (!start || !Number.isFinite(start.latitude)) throw new UserError('Point de départ requis');
    const at = iso();
    const tour = {
      __typename: 'Tour',
      id: crypto.randomUUID(),
      ref: `T-${(date || at.slice(0, 10)).replace(/-/g, '').slice(2)}-${shortId(3)}`,
      name: name || null,
      date: date || at.slice(0, 10),
      slot,
      startTime: startTime || `${date || at.slice(0, 10)}T${slot === 'NIGHT' ? '03:00' : '08:00'}:00.000Z`,
      start, end: end || start,
      courierId: courierId || null,
      status: courierId ? 'ASSIGNED' : 'DRAFT',
      dedicatedCustomerId: dedicatedCustomerId || null,
      orderIds: [],
      customerIds: [],
      estimatedKm: 0,
      estimatedMinutes: 0,
      alerts: [],
      notices: [],
      incidents: [],
      createdAt: at,
      updatedAt: at,
    };
    await store.put('Tour', tour);
    return tour;
  }

  // ---------- Construction des points ----------
  // Une demande donne un point de collecte et un point de livraison ; les colis d'un même client
  // à la même adresse sont regroupés sur un seul point.
  function buildStops(tour, orderList, parcelsByOrder) {
    const stops = [];
    const find = (type, customerId, address) => stops.find((s) => s.type === type && s.customerId === customerId
      && distanceMeters(s.address, address) <= SAME_PLACE_METERS);
    for (const o of orderList) {
      const parcelIds = (parcelsByOrder.get(o.id) || []).map((p) => p.id);
      let pickup = find('PICKUP', o.customerId, o.pickup.address);
      if (!pickup) {
        pickup = newStop(tour, 'PICKUP', o.customerId, o.pickup);
        stops.push(pickup);
      }
      pickup.orderIds.push(o.id);
      pickup.parcelIds.push(...parcelIds);
      let delivery = find('DELIVERY', o.customerId, o.delivery.address);
      if (!delivery) {
        delivery = newStop(tour, 'DELIVERY', o.customerId, o.delivery);
        stops.push(delivery);
      }
      delivery.orderIds.push(o.id);
      delivery.parcelIds.push(...parcelIds);
      if (!delivery.requires.includes(pickup.id)) delivery.requires.push(pickup.id);
      // Contraintes horaires : la plus stricte des demandes regroupées l'emporte
      if (o.deadlineAt && (!delivery.deadlineAt || o.deadlineAt < delivery.deadlineAt)) delivery.deadlineAt = o.deadlineAt;
      if (o.windowStart) delivery.windowStart = o.windowStart;
      if (o.windowEnd) delivery.windowEnd = o.windowEnd;
      delivery.hard = delivery.hard || Boolean(o.hardConstraint);
    }
    return stops;
  }

  function newStop(tour, type, customerId, point) {
    return {
      __typename: 'Stop',
      id: crypto.randomUUID(),
      tourId: tour.id,
      courierId: tour.courierId || null,
      type,
      customerId,
      address: point.address,
      contact: point.contact,
      instructions: point.instructions,
      orderIds: [],
      parcelIds: [],
      requires: [],
      deadlineAt: null,
      windowStart: null,
      windowEnd: null,
      hard: false,
      locked: false,
      status: 'TODO',
      sequence: 0,
      eta: null,
      createdAt: iso(),
      updatedAt: iso(),
    };
  }

  async function loadOrders(orderIds) {
    const list = [];
    const parcelsByOrder = new Map();
    for (const id of orderIds) {
      const o = await store.get('Order', id);
      if (!o) throw new UserError(`Demande introuvable : ${id}`);
      list.push(o);
      parcelsByOrder.set(id, await orders.parcelsOf(id));
    }
    return { list, parcelsByOrder };
  }

  async function replan(tour, keepLocks = new Map()) {
    const { list, parcelsByOrder } = await loadOrders(tour.orderIds);
    const old = await stopsOf(tour.id);
    const stops = buildStops(tour, list, parcelsByOrder);
    for (const s of stops) {
      const prev = old.find((o) => o.type === s.type && o.customerId === s.customerId && distanceMeters(o.address, s.address) <= SAME_PLACE_METERS);
      if (prev && (prev.locked || keepLocks.has(prev.id))) { s.locked = true; s.sequence = prev.sequence; }
    }
    const result = plan(tour.start, stops, tour.startTime, { slot: tour.slot });
    for (const o of old) await store.delete('Stop', o.id);
    for (const s of result.ordered) await store.put('Stop', s);
    return store.update('Tour', tour.id, {
      estimatedKm: result.totalKm,
      estimatedMinutes: result.totalMinutes,
      alerts: result.alerts,
      customerIds: [...new Set(list.map((o) => o.customerId))],
      updatedAt: iso(),
    });
  }

  // ---------- Insertion manuelle de demandes (spec §6.1, §6.4 V1) ----------
  async function addOrders(identity, { tourId, orderIds }) {
    requireStaff(identity);
    const tour = await getTour(tourId);
    if (['DONE', 'VALIDATED'].includes(tour.status)) throw new UserError('Tournée terminée');
    const { list, parcelsByOrder } = await loadOrders(orderIds);
    for (const o of list) {
      if (o.status === 'AWAITING_PAYMENT') throw new UserError(`${o.ref} : une demande non payée n’entre jamais dans une tournée`);
      if (o.status === 'TO_FIX') throw new UserError(`${o.ref} : corrigez d’abord les anomalies de la demande`);
      if (o.status !== 'CREATED') throw new UserError(`${o.ref} : demande déjà planifiée ou clôturée`);
      if (tour.dedicatedCustomerId && o.customerId !== tour.dedicatedCustomerId) throw new UserError(`${o.ref} : tournée dédiée à un autre client`);
      const customer = await store.get('Customer', o.customerId);
      const others = tour.customerIds.filter((c) => c !== o.customerId);
      if (customer?.dedicated && (others.length || list.some((x) => x.customerId !== o.customerId))) {
        throw new UserError(`${o.ref} : ce client est toujours en tournée dédiée`);
      }
    }

    if (tour.status === 'IN_PROGRESS') return appendToStartedTour(identity, tour, list, parcelsByOrder);

    const updated = await store.update('Tour', tourId, { orderIds: [...tour.orderIds, ...orderIds], updatedAt: iso() });
    for (const o of list) await assignOrder(o, parcelsByOrder.get(o.id), tour, identity);
    return replan(updated);
  }

  async function assignOrder(order, parcels, tour, identity) {
    await store.update('Order', order.id, { status: 'PLANNED', tourId: tour.id, updatedAt: iso() }, { status: 'CREATED' });
    for (const p of parcels) {
      await store.update('Parcel', p.id, { tourId: tour.id, updatedAt: iso() });
      await orders.addEvent({ ...p, tourId: tour.id }, 'ASSIGNED_TO_TOUR', { actor: identity.sub, tourId: tour.id });
    }
  }

  // Tournée démarrée : gelée, seuls des ajouts en fin de tournée sous un seuil de détour (spec §7.2)
  async function appendToStartedTour(identity, tour, list, parcelsByOrder) {
    const current = await stopsOf(tour.id);
    const newStops = buildStops(tour, list, parcelsByOrder);
    const last = [...current].reverse().find(Boolean);
    const detour = appendDetourKm(last ? last.address : tour.start, newStops);
    if (detour > cfg.maxAddDetourKm) {
      throw new UserError(`Ajout refusé : détour de ${detour} km (maximum ${cfg.maxAddDetourKm} km sur une tournée démarrée)`);
    }
    let seq = current.length;
    for (const s of newStops) { s.sequence = ++seq; await store.put('Stop', s); }
    for (const o of list) await assignOrder(o, parcelsByOrder.get(o.id), tour, identity);
    const notice = { at: iso(), message: `${newStops.length} point(s) ajouté(s) en fin de tournée (+${detour} km)` };
    return store.update('Tour', tour.id, {
      orderIds: [...tour.orderIds, ...list.map((o) => o.id)],
      customerIds: [...new Set([...tour.customerIds, ...list.map((o) => o.customerId)])],
      estimatedKm: round2(tour.estimatedKm + detour),
      notices: [...(tour.notices || []), notice],
      updatedAt: iso(),
    });
  }

  async function removeOrder(identity, { tourId, orderId, reason }) {
    requireStaff(identity);
    const tour = await getTour(tourId);
    if (tour.status === 'IN_PROGRESS' && !reason) throw new UserError('Tournée démarrée : indiquez le motif du retrait');
    if (['DONE', 'VALIDATED'].includes(tour.status)) throw new UserError('Tournée terminée');
    if (!tour.orderIds.includes(orderId)) throw new UserError('Demande absente de cette tournée');
    const stops = await stopsOf(tourId);
    if (stops.some((s) => s.orderIds.includes(orderId) && s.status !== 'TODO')) throw new UserError('Un point de cette demande est déjà réalisé');
    await store.update('Order', orderId, { status: 'CREATED', tourId: null, updatedAt: iso() });
    for (const p of await orders.parcelsOf(orderId)) await store.update('Parcel', p.id, { tourId: null, updatedAt: iso() });
    const updated = await store.update('Tour', tourId, {
      orderIds: tour.orderIds.filter((id) => id !== orderId),
      notices: reason ? [...(tour.notices || []), { at: iso(), message: `Demande retirée : ${reason}` }] : tour.notices,
      updatedAt: iso(),
    });
    return replan(updated);
  }

  async function lockStop(identity, { stopId, locked }) {
    requireStaff(identity);
    const stop = await store.get('Stop', stopId);
    if (!stop) throw new UserError('Point introuvable');
    return store.update('Stop', stopId, { locked: Boolean(locked), updatedAt: iso() });
  }

  async function optimize(identity, { tourId }) {
    requireStaff(identity);
    const tour = await getTour(tourId);
    if (!['DRAFT', 'PLANNED', 'ASSIGNED', 'ACCEPTED'].includes(tour.status)) throw new UserError('Une tournée démarrée n’est plus réordonnée');
    return replan(tour);
  }

  async function assign(identity, { tourId, courierId }) {
    requireStaff(identity);
    const tour = await getTour(tourId);
    if (!['DRAFT', 'PLANNED', 'ASSIGNED', 'ACCEPTED'].includes(tour.status)) throw new UserError('Tournée déjà démarrée');
    for (const s of await stopsOf(tourId)) await store.update('Stop', s.id, { courierId });
    return store.update('Tour', tourId, { courierId, status: 'ASSIGNED', updatedAt: iso() });
  }

  async function accept(identity, { tourId }) {
    const tour = await getTour(tourId);
    if (tour.courierId !== identity.sub) throw new UserError('Tournée introuvable');
    return store.update('Tour', tourId, { status: 'ACCEPTED', updatedAt: iso() }, { status: 'ASSIGNED' });
  }

  async function start(identity, { tourId }) {
    const tour = await getTour(tourId);
    if (tour.courierId !== identity.sub) throw new UserError('Tournée introuvable');
    if (!['ASSIGNED', 'ACCEPTED'].includes(tour.status)) throw new UserError('Cette tournée ne peut pas être démarrée');
    if (tour.alerts?.some((a) => a.code === 'DEADLINE_MISSED') && !tour.alertsAcknowledged) {
      throw new UserError('Heure limite impossible à tenir : le dispatcher doit revoir la tournée');
    }
    return store.update('Tour', tourId, { status: 'IN_PROGRESS', startedAt: iso(), updatedAt: iso() });
  }

  // ---------- Preuves exigées ----------
  const profileCache = new Map();
  async function profileFor(parcel, order) {
    const customer = await store.get('Customer', parcel.customerId);
    const customerType = customer?.customerTypeId ? await store.get('CustomerType', customer.customerTypeId) : null;
    const id = P.resolveProfileId({ customerType, customer, order, parcel });
    if (!id) return null;
    if (!profileCache.has(id)) profileCache.set(id, await store.get('ProofProfile', id));
    return profileCache.get(id);
  }

  async function stopRequirements(stop, parcelIds = stop.parcelIds) {
    const items = [];
    for (const id of parcelIds) {
      const parcel = await store.get('Parcel', id);
      if (!parcel) continue;
      const order = parcel.orderId ? await store.get('Order', parcel.orderId) : null;
      items.push({ parcel, profile: await profileFor(parcel, order) });
    }
    return P.aggregateStop(items, stop.type);
  }

  // Vue livreur d'une tournée : points ordonnés, colis, preuves exigées, commentaires prédéfinis
  async function courierView(identity, { tourId }) {
    const tour = await getTour(tourId);
    if (tour.courierId !== identity.sub && !isStaff(identity)) throw new UserError('Tournée introuvable');
    const stops = [];
    for (const s of await stopsOf(tourId)) {
      const parcels = [];
      for (const id of s.parcelIds) { const p = await store.get('Parcel', id); if (p) parcels.push(p); }
      stops.push({ ...s, parcels, requirements: await stopRequirements(s) });
    }
    const presets = (await store.query('CommentPreset', 'byActive', 'active', 'yes')).sort((a, b) => a.label.localeCompare(b.label));
    return { tour, stops, presets };
  }

  // ---------- Scan (spec §4.2) ----------
  async function scan(identity, { tourId, stopId, code }) {
    const tour = await getTour(tourId);
    if (tour.courierId !== identity.sub) throw new UserError('Tournée introuvable');
    const stop = await store.get('Stop', stopId);
    if (!stop || stop.tourId !== tourId) throw new UserError('Point introuvable');
    const decoded = decodeCode(labelSecret, code);
    if (decoded.error) throw new UserError(decoded.error);
    if (decoded.customerTag !== customerTag(stop.customerId)) throw new UserError('Colis d’un autre client : ne pas le prendre à ce point');
    const parcel = await store.get('Parcel', decoded.parcelId);
    if (!parcel) throw new UserError('Colis inconnu');
    if (parcel.labelStatus === 'UNUSED') throw new UserError('Étiquette abandonnée : elle ne peut plus être utilisée');
    if (parcel.labelStatus === 'RESERVED') {
      if (stop.type !== 'PICKUP' || parcel.tourId !== tourId) throw new UserError('Étiquette en réserve d’une autre tournée');
      return { parcel, reserved: true };
    }
    if (!stop.parcelIds.includes(parcel.id)) throw new UserError('Ce colis n’est pas prévu à ce point');
    return { parcel, reserved: false };
  }

  // Une étiquette en réserve devient un vrai colis quand elle est scannée à la collecte (spec §4.3)
  async function activateReserved(parcel, stop, identity) {
    const orderId = stop.orderIds[0];
    const order = await store.get('Order', orderId);
    const updated = await store.update('Parcel', parcel.id, {
      labelStatus: 'ACTIVE', orderId, size: order.size, updatedAt: iso(),
    }, { labelStatus: 'RESERVED' });
    await store.update('Stop', stop.id, { parcelIds: [...stop.parcelIds, parcel.id] });
    const delivery = (await stopsOf(stop.tourId)).find((s) => s.type === 'DELIVERY' && s.orderIds.includes(orderId));
    if (delivery) await store.update('Stop', delivery.id, { parcelIds: [...delivery.parcelIds, parcel.id] });
    await orders.addEvent(updated, 'CREATED', { actor: identity.sub, method: 'SCAN', internalComment: 'Étiquette en réserve utilisée à la collecte' });
    return updated;
  }

  async function checkComment(comment, kind) {
    if (!comment || (!comment.presetId && !comment.text)) return { visible: null, internal: null, preset: null };
    let preset = null;
    if (comment.presetId) {
      preset = await store.get('CommentPreset', comment.presetId);
      if (!preset || preset.kind !== kind) throw new UserError('Commentaire prédéfini inconnu pour cette action');
    }
    // Texte libre : interne par défaut (spec §5.4)
    const visible = preset && preset.clientVisible ? preset.label : null;
    const internal = [preset && !preset.clientVisible ? preset.label : null, comment.text || null].filter(Boolean).join(' — ') || null;
    return { visible, internal, preset };
  }

  // ---------- Collecte / livraison d'un point (spec §5.3) ----------
  async function submitStop(identity, { stopId, parcelIds, scannedCodes = [], proofs = {}, position, comment, deviceId, method }) {
    const stop = await store.get('Stop', stopId);
    if (!stop) throw new UserError('Point introuvable');
    const tour = await getTour(stop.tourId);
    if (tour.courierId !== identity.sub) throw new UserError('Point introuvable');
    if (tour.status !== 'IN_PROGRESS') throw new UserError('Démarrez la tournée avant de valider un point');
    if (stop.status !== 'TODO') throw new UserError('Point déjà traité : les preuves envoyées ne sont plus modifiables');

    // Scans : contrôle et activation des étiquettes en réserve
    const scannedIds = [];
    let current = stop;
    for (const code of scannedCodes) {
      const r = await scan(identity, { tourId: tour.id, stopId, code });
      if (r.reserved) {
        await activateReserved(r.parcel, current, identity);
        current = await store.get('Stop', stopId);
      }
      scannedIds.push(r.parcel.id);
    }
    const handled = [...new Set([...(parcelIds || current.parcelIds), ...scannedIds])].filter((id) => current.parcelIds.includes(id));
    if (!handled.length) throw new UserError('Aucun colis sélectionné');

    const required = await stopRequirements(current, handled);
    let otpOk = false;
    if (required.perStop.otp) {
      const secrets = await Promise.all(current.orderIds.map((id) => store.get('OrderSecret', id)));
      otpOk = Boolean(proofs.otpCode) && secrets.some((s) => s && s.otpCode === String(proofs.otpCode).trim());
    }
    const missing = P.missingProofs(required, { ...proofs, scannedParcelIds: scannedIds, position, otpOk }, handled);
    if (missing.length) throw new UserError(`Preuves manquantes : ${P.describeMissing(missing)}`);

    const kind = current.type === 'PICKUP' ? 'PICKUP' : 'DELIVERY';
    const c = await checkComment(comment, kind);
    const distance = position ? Math.round(distanceMeters(position, current.address)) : null;
    const alert = distance !== null && distance > cfg.distanceAlertMeters;
    const eventType = kind === 'PICKUP' ? 'PICKED_UP' : 'DELIVERED';
    const storedProofs = {
      scanned: scannedIds, photoKeys: proofs.photoKeys || [], signatureKey: proofs.signatureKey || null,
      signerName: proofs.signerName || null, otpVerified: required.perStop.otp ? otpOk : null,
    };

    for (const id of handled) {
      const parcel = await store.get('Parcel', id);
      await store.update('Parcel', id, { status: kind === 'PICKUP' ? 'PICKED_UP' : 'DELIVERED', updatedAt: iso() });
      await orders.addEvent(parcel, eventType, {
        tourId: tour.id, stopId, courierId: identity.sub, deviceId, method: method || (scannedIds.includes(id) ? 'SCAN' : 'MANUAL'),
        proofs: storedProofs, comment: c.visible, internalComment: c.internal,
        expected: current.address, actual: position, distanceMeters: distance, distanceAlert: alert,
      });
    }
    const missingHere = current.parcelIds.filter((id) => !handled.includes(id));
    const updatedStop = await store.update('Stop', stopId, {
      status: missingHere.length ? 'PARTIAL' : 'DONE', doneAt: iso(), distanceMeters: distance, distanceAlert: alert, updatedAt: iso(),
    }, { status: 'TODO' });
    await refreshOrders(current.orderIds);
    return updatedStop;
  }

  // ---------- Échec (spec §7) ----------
  async function failStop(identity, { stopId, parcelIds, comment, proofs = {}, position, deviceId }) {
    const stop = await store.get('Stop', stopId);
    if (!stop) throw new UserError('Point introuvable');
    const tour = await getTour(stop.tourId);
    if (tour.courierId !== identity.sub) throw new UserError('Point introuvable');
    if (tour.status !== 'IN_PROGRESS' || stop.status !== 'TODO') throw new UserError('Ce point ne peut plus être modifié');
    if (!comment?.presetId) throw new UserError('Choisissez le motif de l’échec');
    const c = await checkComment(comment, 'FAILURE');
    if (cfg.failurePhotoRequired && !(proofs.photoKeys && proofs.photoKeys.length)) throw new UserError('Ajoutez une photo pour justifier l’échec');
    const failed = parcelIds && parcelIds.length ? parcelIds : stop.parcelIds;
    const distance = position ? Math.round(distanceMeters(position, stop.address)) : null;
    for (const id of failed) {
      const parcel = await store.get('Parcel', id);
      if (!parcel) continue;
      await store.update('Parcel', id, { status: 'FAILED', updatedAt: iso() });
      await orders.addEvent(parcel, 'FAILED', {
        tourId: tour.id, stopId, courierId: identity.sub, deviceId,
        proofs: { photoKeys: proofs.photoKeys || [] }, comment: c.visible, internalComment: c.internal || c.preset.label,
        expected: stop.address, actual: position, distanceMeters: distance,
        distanceAlert: distance !== null && distance > cfg.distanceAlertMeters,
      });
    }
    const updated = await store.update('Stop', stopId, { status: 'FAILED', doneAt: iso(), failureReason: c.preset.label, updatedAt: iso() }, { status: 'TODO' });
    // Une collecte échouée rend la livraison correspondante impossible
    if (stop.type === 'PICKUP') {
      for (const s of await stopsOf(tour.id)) {
        if (s.type === 'DELIVERY' && s.status === 'TODO' && s.requires.includes(stop.id)) {
          await store.update('Stop', s.id, { status: 'FAILED', failureReason: 'Collecte échouée', doneAt: iso() });
        }
      }
    }
    await refreshOrders(stop.orderIds, { failedReason: c.preset.label });
    return updated;
  }

  // Statut des demandes déduit de leurs colis (spec §13)
  async function refreshOrders(orderIds, { failedReason } = {}) {
    for (const id of orderIds) {
      const order = await store.get('Order', id);
      if (!order || order.status === 'CANCELLED') continue;
      const parcels = (await orders.parcelsOf(id)).filter((p) => p.labelStatus === 'ACTIVE');
      const st = parcels.map((p) => p.status);
      let status = order.status;
      if (st.length && st.every((s) => s === 'DELIVERED')) status = 'DONE';
      else if (st.some((s) => s === 'FAILED')) status = st.every((s) => ['FAILED', 'DELIVERED'].includes(s)) ? 'PARTIALLY_FAILED' : 'IN_PROGRESS';
      else if (st.some((s) => ['PICKED_UP', 'DELIVERED'].includes(s))) status = 'IN_PROGRESS';
      if (status !== order.status) {
        const updated = await store.update('Order', id, { status, updatedAt: iso() });
        if (ctx.hooks?.onOrderStatus) await ctx.hooks.onOrderStatus(updated, { failedReason });
      }
    }
  }

  // ---------- Clôture (spec §4.3, §9) ----------
  async function close(identity, { tourId, reason }) {
    const tour = await getTour(tourId);
    const staff = isStaff(identity);
    if (tour.courierId !== identity.sub && !staff) throw new UserError('Tournée introuvable');
    if (tour.status !== 'IN_PROGRESS') throw new UserError('Seule une tournée en cours peut être clôturée');
    const stops = await stopsOf(tourId);
    const todo = stops.filter((s) => s.status === 'TODO');
    if (todo.length && !(staff && reason)) throw new UserError(`${todo.length} point(s) restant(s) : terminez-les ou demandez la clôture à Wabap`);

    // Étiquettes en réserve jamais scannées : abandonnées, sans erreur ni alerte
    const reserved = (await store.query('Parcel', 'byTour', 'tourId', tourId)).filter((p) => p.labelStatus === 'RESERVED');
    for (const p of reserved) await store.update('Parcel', p.id, { labelStatus: 'UNUSED', updatedAt: iso() });

    // Mode strict : tout colis attendu non collecté ou non livré crée un incident
    const incidents = [];
    for (const customerId of tour.customerIds) {
      const customer = await store.get('Customer', customerId);
      if ((customer?.labelMode || 'FLEXIBLE') !== 'STRICT') continue;
      const parcels = (await store.query('Parcel', 'byTour', 'tourId', tourId))
        .filter((p) => p.customerId === customerId && p.expected && p.labelStatus === 'ACTIVE' && !['DELIVERED', 'FAILED'].includes(p.status));
      for (const p of parcels) {
        const motive = p.status === 'AWAITING_PICKUP' ? 'Colis non collecté' : 'Colis collecté mais non livré';
        await orders.addEvent(p, 'INCIDENT', { tourId, actor: identity.sub, internalComment: motive });
        incidents.push({ parcelId: p.id, customerId, motive, status: 'OPEN' });
      }
    }
    for (const s of todo) await store.update('Stop', s.id, { status: 'FAILED', failureReason: `Clôture forcée : ${reason}` });
    const closed = await store.update('Tour', tourId, {
      status: 'DONE', closedAt: iso(), incidents: [...(tour.incidents || []), ...incidents], updatedAt: iso(),
      notices: reason ? [...(tour.notices || []), { at: iso(), message: `Clôture forcée : ${reason}` }] : tour.notices,
    });
    if (ctx.hooks?.onTourClosed) await ctx.hooks.onTourClosed(closed, stops);
    return closed;
  }

  // ---------- Vue client cloisonnée (spec §11 ter) ----------
  // Le filtrage est fait ici, côté serveur : jamais seulement dans l'interface.
  async function clientView(identity, { tourId }) {
    const tour = await getTour(tourId);
    const cid = customerIdFor(identity);
    const mine = (await stopsOf(tourId)).filter((s) => s.customerId === cid);
    if (!mine.length && !isStaff(identity)) throw new UserError('Tournée introuvable');
    const customer = await store.get('Customer', cid);
    const opts = { route: 'NONE', showEta: false, showStopsBefore: false, showLivePosition: true, ...(customer?.tracking || {}) };
    const all = await stopsOf(tourId);
    const remainingMine = mine.filter((s) => s.status === 'TODO');
    let courier = null;
    if (opts.showLivePosition && tour.status === 'IN_PROGRESS' && remainingMine.length && tour.courierId) {
      const pos = await store.get('CourierPosition', tour.courierId);
      if (pos) courier = { latitude: pos.latitude, longitude: pos.longitude, at: pos.at };
    }
    return {
      tourId: tour.id,
      ref: tour.ref,
      date: tour.date,
      status: tour.status,
      courier,
      stops: mine.map((s) => ({
        id: s.id, type: s.type, address: s.address, status: s.status, parcelIds: s.parcelIds,
        eta: opts.showEta ? s.eta : null,
        stopsBefore: opts.showStopsBefore ? all.filter((x) => x.sequence < s.sequence && x.status === 'TODO').length : null,
      })),
      route: opts.route === 'OWN' ? mine.map((s) => s.address) : null,
    };
  }

  return {
    createTour, addOrders, removeOrder, lockStop, optimize, assign, accept, start,
    courierView, scan, submitStop, failStop, close, clientView, stopsOf, stopRequirements, buildStops,
  };
}

module.exports = { createTours, DEFAULT_CONFIG };

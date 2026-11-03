// Demandes de livraison et colis (spec §3, §4, §4.4).
// Pipeline d'ingestion : connecteur → mapping → normalisation → défauts du client → géocodage → validation.
const crypto = require('crypto');
const N = require('./normalize');
const { shortId, encodeCode } = require('./labels');

class UserError extends Error {}

const SIZES = ['S', 'M', 'L', 'XL'];
const SOURCES = ['CLIENT_APP', 'API', 'IMPORT', 'MANUAL'];

function isStaff(identity) {
  return ['admin', 'wabap', 'dispatch'].some((g) => identity.groups.includes(g));
}

// Un particulier ou un pro occasionnel n'a pas d'organisation : son « client » est son compte
function customerIdFor(identity) {
  return identity.clientName || `IND-${identity.sub}`;
}

function createOrders(ctx) {
  const { store, geocoder, labelSecret } = ctx;
  const now = () => (ctx.now ? ctx.now() : new Date());
  const iso = () => now().toISOString();

  // ---------- Historique non modifiable (spec §4.4) ----------
  // Les événements sont seulement ajoutés : aucune opération ne permet de les modifier ou de les supprimer.
  async function addEvent(parcel, type, extra = {}) {
    const at = iso();
    const event = {
      __typename: 'ParcelEvent',
      id: crypto.randomUUID(),
      parcelId: parcel.id,
      orderId: parcel.orderId,
      customerId: parcel.customerId,
      ownerSub: parcel.ownerSub || null,
      type,
      at,
      day: at.slice(0, 10), // index des statistiques par jour
      tourId: extra.tourId ?? parcel.tourId ?? null,
      stopId: extra.stopId ?? null,
      courierId: extra.courierId ?? null,
      deviceId: extra.deviceId ?? null,
      method: extra.method ?? null,
      actor: extra.actor ?? null,
      proofs: extra.proofs ? JSON.stringify(extra.proofs) : null,
      comment: extra.comment ?? null, // visible par le client
      internalComment: extra.internalComment ?? null, // réservé à Wabap
      expectedLatitude: extra.expected?.latitude ?? null,
      expectedLongitude: extra.expected?.longitude ?? null,
      actualLatitude: extra.actual?.latitude ?? null,
      actualLongitude: extra.actual?.longitude ?? null,
      distanceMeters: extra.distanceMeters ?? null,
      distanceAlert: extra.distanceAlert ?? null,
      createdAt: at,
      updatedAt: at,
    };
    await store.put('ParcelEvent', event);
    return event;
  }

  async function history(parcelId) {
    const events = await store.query('ParcelEvent', 'byParcel', 'parcelId', parcelId);
    return events.sort((a, b) => a.at.localeCompare(b.at));
  }

  // ---------- Normalisation d'un point (collecte ou livraison) ----------
  async function normalizePoint(draft, label, anomalies) {
    const address = draft.address && typeof draft.address === 'object' ? { ...draft.address } : N.splitAddress(draft.address);
    const contact = {
      name: N.normalizeName(draft.name),
      phone: N.normalizePhone(draft.phone),
      email: N.normalizeEmail(draft.email),
    };
    if (draft.phone && !contact.phone) anomalies.push({ code: 'INVALID_PHONE', field: `${label}.phone`, message: `Téléphone de ${label === 'pickup' ? 'collecte' : 'livraison'} invalide : ${draft.phone}` });
    if (draft.email && !contact.email) anomalies.push({ code: 'INVALID_EMAIL', field: `${label}.email`, message: `E-mail invalide : ${draft.email}` });

    if (!address || !(address.street || address.formatted)) {
      anomalies.push({ code: 'MISSING_ADDRESS', field: `${label}.address`, message: `Adresse de ${label === 'pickup' ? 'collecte' : 'livraison'} manquante` });
      return { address: null, contact, instructions: N.cleanText(draft.instructions) };
    }
    if (!Number.isFinite(address.latitude) || !Number.isFinite(address.longitude)) {
      const query = address.formatted || N.formatAddress(address);
      const geo = geocoder ? await geocoder.geocode(query) : null;
      if (!geo) {
        anomalies.push({ code: 'ADDRESS_NOT_FOUND', field: `${label}.address`, message: `Adresse introuvable : ${query}` });
      } else {
        Object.assign(address, {
          latitude: geo.latitude,
          longitude: geo.longitude,
          postalCode: address.postalCode || geo.postalCode || null,
          city: address.city || geo.city || null,
          geocodeQuality: geo.quality || null,
        });
        address.formatted = geo.formatted || query;
      }
    }
    address.formatted = address.formatted || N.formatAddress(address);
    address.country = address.country || 'FR';
    return { address, contact, instructions: N.cleanText(draft.instructions) };
  }

  // ---------- Ingestion ----------
  // record : données de la source ; mapping appliqué si un connecteur est fourni.
  async function ingest(identity, { customerId, source, connectorId, record }) {
    if (!SOURCES.includes(source)) throw new UserError('Source inconnue');
    const staff = isStaff(identity);
    const cid = staff && customerId ? customerId : customerIdFor(identity);
    if (!staff && customerId && customerId !== cid) throw new UserError('Accès refusé');

    const customer = await store.get('Customer', cid);
    const connector = connectorId ? await store.get('Connector', connectorId) : null;
    if (connector && connector.customerId !== cid) throw new UserError('Connecteur d’un autre client');
    const mapping = connector && (typeof connector.mapping === 'string' ? JSON.parse(connector.mapping) : connector.mapping);
    const d = mapping ? N.applyMapping(record, mapping) : { ...record };
    const defaults = customer ? (typeof customer.defaults === 'string' ? JSON.parse(customer.defaults) : customer.defaults) || {} : {};

    const anomalies = [];
    // Enrichissement par les défauts du client (spec §4.1, étape 4)
    const pickupDraft = {
      address: d.pickupAddress || defaults.pickupAddress,
      name: d.pickupName || defaults.pickupName,
      phone: d.pickupPhone || defaults.pickupPhone,
      email: d.pickupEmail,
      instructions: d.pickupInstructions || defaults.pickupInstructions,
    };
    const deliveryDraft = {
      address: d.deliveryAddress,
      name: d.deliveryName,
      phone: d.deliveryPhone,
      email: d.deliveryEmail,
      instructions: d.instructions || d.deliveryInstructions,
    };
    const pickup = await normalizePoint(pickupDraft, 'pickup', anomalies);
    const delivery = await normalizePoint(deliveryDraft, 'delivery', anomalies);

    const parcelCount = d.parcelCount !== undefined ? parseInt(d.parcelCount, 10) : (defaults.parcelCount || 1);
    if (!Number.isInteger(parcelCount) || parcelCount < 1 || parcelCount > 500) {
      anomalies.push({ code: 'INVALID_PARCEL_COUNT', field: 'parcelCount', message: `Nombre de colis invalide : ${d.parcelCount}` });
    }
    const size = String(d.size || defaults.size || 'S').toUpperCase();
    if (!SIZES.includes(size)) anomalies.push({ code: 'INVALID_SIZE', field: 'size', message: `Taille de colis inconnue : ${d.size}` });
    const weightKg = d.weightKg !== undefined && d.weightKg !== '' ? Number(String(d.weightKg).replace(',', '.')) : null;
    if (weightKg !== null && !(weightKg >= 0)) anomalies.push({ code: 'INVALID_WEIGHT', field: 'weightKg', message: `Poids invalide : ${d.weightKg}` });

    const externalRef = N.cleanText(d.externalRef);
    if (externalRef) {
      const dup = await store.query('Order', 'byCustomerRef', 'customerId', cid, { sortKey: 'externalRef', sortValue: externalRef });
      if (dup.some((o) => o.status !== 'CANCELLED')) anomalies.push({ code: 'DUPLICATE', field: 'externalRef', message: `Référence déjà reçue : ${externalRef}` });
    }

    const at = iso();
    const order = {
      __typename: 'Order',
      id: crypto.randomUUID(),
      ref: `D-${at.slice(2, 10).replace(/-/g, '')}-${shortId(3)}`,
      customerId: cid,
      ownerSub: cid.startsWith('IND-') ? identity.sub : null,
      customerName: customer?.name || identity.name || null,
      source,
      connectorId: connectorId || null,
      externalRef,
      status: anomalies.length ? 'TO_FIX' : 'CREATED',
      pickup,
      delivery,
      parcelCount: Number.isInteger(parcelCount) && parcelCount > 0 ? parcelCount : 1,
      size: SIZES.includes(size) ? size : 'S',
      weightKg,
      deadlineAt: d.deadlineAt || defaults.deadlineAt || null,
      windowStart: d.windowStart || null,
      windowEnd: d.windowEnd || null,
      hardConstraint: d.hardConstraint !== undefined ? Boolean(d.hardConstraint) : Boolean(d.deadlineAt || defaults.deadlineAt),
      priority: d.priority ? Number(d.priority) : 0,
      proofProfileId: d.proofProfileId || null,
      billingMode: customer?.billingMode || 'PER_ORDER',
      anomalies,
      rawInput: JSON.stringify(record), // traçabilité : donnée brute conservée (spec §4.1, étape 6)
      tourId: null,
      createdBy: identity.sub,
      createdAt: at,
      updatedAt: at,
    };
    await store.put('Order', order);
    order.parcels = await createParcels(order, order.parcelCount, { actor: identity.sub });
    return order;
  }

  async function createParcels(order, count, { actor, reservedForTour = null } = {}) {
    const parcels = [];
    for (let i = 1; i <= count; i++) {
      const id = shortId(6);
      const at = iso();
      const parcel = {
        __typename: 'Parcel',
        id,
        code: encodeCode(labelSecret, id, order.customerId),
        orderId: reservedForTour ? null : order.id,
        customerId: order.customerId,
        ownerSub: order.ownerSub || null,
        index: i,
        total: count,
        size: order.size,
        weightKg: order.weightKg,
        proofProfileId: null,
        status: 'AWAITING_PICKUP',
        labelStatus: reservedForTour ? 'RESERVED' : 'ACTIVE',
        expected: !reservedForTour, // seuls les colis attendus génèrent une alerte s'ils manquent
        tourId: reservedForTour || order.tourId || null,
        createdAt: at,
        updatedAt: at,
      };
      await store.put('Parcel', parcel);
      if (!reservedForTour) await addEvent(parcel, 'CREATED', { actor });
      parcels.push(parcel);
    }
    return parcels;
  }

  // Correction d'une anomalie par le dispatcher : on réapplique la normalisation et la validation
  async function fix(identity, { orderId, patch }) {
    if (!isStaff(identity)) throw new UserError('Réservé aux équipes Wabap');
    const order = await store.get('Order', orderId);
    if (!order) throw new UserError('Demande introuvable');
    if (!['TO_FIX', 'CREATED'].includes(order.status)) throw new UserError('Seules les demandes non planifiées peuvent être corrigées');
    const anomalies = [];
    const point = (label) => ({
      address: patch[`${label}Address`] ?? (order[label].address ? { ...order[label].address } : null),
      name: patch[`${label}Name`] ?? order[label].contact.name,
      phone: patch[`${label}Phone`] ?? order[label].contact.phone,
      email: patch[`${label}Email`] ?? order[label].contact.email,
      instructions: patch[`${label}Instructions`] ?? order[label].instructions,
    });
    const pickup = await normalizePoint(point('pickup'), 'pickup', anomalies);
    const delivery = await normalizePoint(point('delivery'), 'delivery', anomalies);
    // Un doublon reste signalé tant que le dispatcher ne le confirme pas
    if (order.anomalies.some((a) => a.code === 'DUPLICATE') && !patch.confirmNotDuplicate) {
      anomalies.push(order.anomalies.find((a) => a.code === 'DUPLICATE'));
    }
    return store.update('Order', orderId, {
      pickup, delivery, anomalies,
      status: anomalies.length ? 'TO_FIX' : 'CREATED',
      updatedAt: iso(),
    }, { status: order.status });
  }

  async function parcelsOf(orderId) {
    return (await store.query('Parcel', 'byOrder', 'orderId', orderId)).sort((a, b) => a.index - b.index);
  }

  return { ingest, fix, addEvent, history, createParcels, parcelsOf, normalizePoint };
}

module.exports = { createOrders, UserError, isStaff, customerIdFor, SIZES };

// Règles métier des courses à la demande. Aucune dépendance AWS directe :
// le stockage, Stripe, Google et l'horloge sont injectés (ce qui rend tout testable hors ligne).
const crypto = require('crypto');
const geohash = require('./geohash');
const { quote: computeQuote, SIZES, haversineKm, round2 } = require('./pricing');
const { ConditionFailed } = require('./store');

class UserError extends Error {}

const VEHICLES = ['BIKE', 'MOTORBIKE', 'CAR', 'VAN'];
const URGENCIES = ['STANDARD', 'EXPRESS'];

// Étapes autorisées pour le livreur
const COURIER_FLOW = {
  ASSIGNED: ['PICKING_UP'],
  PICKING_UP: ['PICKED_UP'],
  PICKED_UP: ['DELIVERING'],
  DELIVERING: ['COMPLETED', 'ISSUE'],
};
const CLIENT_CANCELLABLE = ['AWAITING_PAYMENT', 'PENDING', 'ASSIGNED', 'PICKING_UP'];
const ADMIN_CANCELLABLE = [...CLIENT_CANCELLABLE, 'PICKED_UP', 'DELIVERING', 'ISSUE'];
const MAX_CODE_ATTEMPTS = 5;
const DISPATCH_RADIUS_KM = 15;

function isStaff(identity) {
  return identity.groups.includes('admin') || identity.groups.includes('wabap');
}
function requireCourier(identity) {
  if (!identity.groups.includes('livreur')) throw new UserError('Réservé aux livreurs');
}

function cleanStop(s, label) {
  const stop = {
    address: String((s && s.address) || '').trim(),
    latitude: Number(s && s.latitude),
    longitude: Number(s && s.longitude),
    contactName: String((s && s.contactName) || '').trim() || null,
    phone: String((s && s.phone) || '').trim() || null,
    instructions: String((s && s.instructions) || '').trim() || null,
  };
  if (!stop.address) throw new UserError(`Adresse de ${label} manquante`);
  if (!Number.isFinite(stop.latitude) || !Number.isFinite(stop.longitude)
    || Math.abs(stop.latitude) > 90 || Math.abs(stop.longitude) > 180) {
    throw new UserError(`Coordonnées de ${label} invalides`);
  }
  return stop;
}

function createService({ store, stripe, google, now = () => new Date(), log = console }) {
  const iso = () => now().toISOString();

  async function loadTarif(identity) {
    if (identity.clientName) {
      const org = await store.get('Tarif', identity.clientName);
      if (org) return org;
    }
    return store.get('Tarif', 'default');
  }

  async function addEvent(course, status, extra = {}) {
    const at = iso();
    await store.put('CourseEvent', {
      __typename: 'CourseEvent',
      id: crypto.randomUUID(),
      courseId: course.id,
      clientId: course.clientId,
      courierId: course.courierId || null,
      status,
      message: extra.message || null,
      latitude: extra.latitude ?? null,
      longitude: extra.longitude ?? null,
      createdAt: at,
      updatedAt: at,
    });
  }

  async function getCourse(id) {
    const c = await store.get('Course', id);
    if (!c) throw new UserError('Course introuvable');
    return c;
  }

  async function quoteCourse(identity, args) {
    const pickup = cleanStop(args.pickup, 'retrait');
    const dropoff = cleanStop(args.dropoff, 'livraison');
    if (!SIZES.includes(args.packageSize)) throw new UserError('Taille de colis invalide');
    if (!URGENCIES.includes(args.urgency)) throw new UserError('Délai invalide');
    const route = await google.route(pickup, dropoff);
    const tarif = await loadTarif(identity);
    return { ...computeQuote({ route, packageSize: args.packageSize, urgency: args.urgency, tarif }), tarif, pickup, dropoff };
  }

  async function createCourse(identity, { input }) {
    const q = await quoteCourse(identity, input);
    const option = input.vehicle ? q.options.find((o) => o.vehicle === input.vehicle) : q.options[0];
    if (!option) throw new UserError('Aucun véhicule ne peut faire cette course (distance ou taille du colis)');

    const invoice = Boolean(identity.clientName && q.tarif && q.tarif.id === identity.clientName && q.tarif.invoice);
    const at = iso();
    const id = crypto.randomUUID();
    const course = {
      __typename: 'Course',
      id,
      ref: `WB-${at.slice(2, 10).replace(/-/g, '')}-${id.slice(0, 4).toUpperCase()}`,
      owner: identity.clientName || null,
      clientId: identity.sub,
      clientName: identity.name || identity.email || null,
      courierId: null,
      status: 'AWAITING_PAYMENT',
      zone: geohash.encode(q.pickup.latitude, q.pickup.longitude, 5),
      area: geohash.encode(q.pickup.latitude, q.pickup.longitude, 4),
      pickup: q.pickup,
      dropoff: q.dropoff,
      packageSize: input.packageSize,
      packageDescription: String(input.packageDescription || '').trim() || null,
      urgency: input.urgency,
      vehicle: option.vehicle,
      distanceKm: q.distanceKm,
      etaMinutes: option.etaMinutes,
      priceHt: option.priceHt,
      priceTva: option.priceTva,
      priceTtc: option.priceTtc,
      courierEarning: option.courierEarning,
      paymentMode: invoice ? 'INVOICE' : 'CARD',
      paymentIntentId: null,
      paymentStatus: invoice ? 'invoice' : 'awaiting_authorization',
      codeAttempts: 0,
      createdAt: at,
      updatedAt: at,
    };

    let paymentClientSecret = null;
    if (!invoice) {
      const pi = await stripe.createAuthorization({ amount: course.priceTtc, courseId: id, ref: course.ref, email: identity.email });
      course.paymentIntentId = pi.id;
      paymentClientSecret = pi.client_secret;
    }
    const deliveryCode = String(crypto.randomInt(0, 10000)).padStart(4, '0');
    await store.put('Course', course);
    await store.put('CourseSecret', { __typename: 'CourseSecret', id, clientId: identity.sub, deliveryCode, createdAt: at, updatedAt: at });
    await addEvent(course, 'AWAITING_PAYMENT');
    return { course, paymentClientSecret, deliveryCode };
  }

  // Appelée par l'app après le paiement (ou directement en mode facture) : la course part aux livreurs.
  async function confirmCoursePayment(identity, { courseId }) {
    const course = await getCourse(courseId);
    if (course.clientId !== identity.sub) throw new UserError('Course introuvable');
    if (course.status !== 'AWAITING_PAYMENT') return course;
    if (course.paymentMode === 'CARD') {
      const pi = await stripe.retrieve(course.paymentIntentId);
      if (pi.status !== 'requires_capture') throw new UserError('Le paiement n’a pas été autorisé');
    }
    try {
      const updated = await store.update('Course', courseId, {
        status: 'PENDING',
        paymentStatus: course.paymentMode === 'CARD' ? 'authorized' : 'invoice',
        updatedAt: iso(),
      }, { status: 'AWAITING_PAYMENT' });
      await addEvent(updated, 'PENDING');
      return updated;
    } catch (e) {
      if (e instanceof ConditionFailed) return getCourse(courseId);
      throw e;
    }
  }

  async function acceptCourse(identity, { courseId }) {
    requireCourier(identity);
    const profile = await store.get('CourierProfile', identity.sub);
    if (!profile || !profile.online) throw new UserError('Passez en ligne pour accepter une course');
    const course = await getCourse(courseId);
    if (course.status !== 'PENDING') throw new UserError('Cette course n’est plus disponible');
    if (course.vehicle !== profile.vehicle) throw new UserError('Votre véhicule ne correspond pas à cette course');

    // 1. Réserver le livreur (échoue s'il a déjà une course en cours)
    try {
      await store.update('CourierProfile', identity.sub, { activeCourseId: courseId, updatedAt: iso() }, { activeCourseId: null });
    } catch (e) {
      if (e instanceof ConditionFailed) throw new UserError('Vous avez déjà une course en cours');
      throw e;
    }
    // 2. Réserver la course (échoue si un autre livreur l'a prise entre-temps)
    try {
      const updated = await store.update('Course', courseId, {
        status: 'ASSIGNED',
        courierId: identity.sub,
        courierName: profile.name || identity.name || null,
        courierPhone: profile.phone || identity.phone || null,
        courierVehicle: profile.vehicle,
        courierRating: profile.rating ?? 5,
        updatedAt: iso(),
      }, { status: 'PENDING', courierId: null });
      await addEvent(updated, 'ASSIGNED');
      return updated;
    } catch (e) {
      await store.update('CourierProfile', identity.sub, { activeCourseId: null, updatedAt: iso() });
      if (e instanceof ConditionFailed) throw new UserError('Cette course vient d’être prise par un autre livreur');
      throw e;
    }
  }

  async function releaseCourier(courierId) {
    if (!courierId) return;
    try {
      await store.update('CourierProfile', courierId, { activeCourseId: null, updatedAt: iso() });
    } catch (e) {
      log.warn(`Libération du livreur ${courierId} impossible : ${e.message}`);
    }
  }

  async function updateCourseStep(identity, { courseId, status, code, reason }) {
    requireCourier(identity);
    const course = await getCourse(courseId);
    if (course.courierId !== identity.sub) throw new UserError('Course introuvable');
    if (!(COURIER_FLOW[course.status] || []).includes(status)) {
      throw new UserError(`Étape impossible : ${course.status} → ${status}`);
    }
    const patch = { status, updatedAt: iso() };

    if (status === 'COMPLETED') {
      if ((course.codeAttempts || 0) >= MAX_CODE_ATTEMPTS) {
        throw new UserError('Trop de codes erronés : contactez le support Wabap');
      }
      const secret = await store.get('CourseSecret', courseId);
      if (!secret || String(code || '').trim() !== secret.deliveryCode) {
        await store.update('Course', courseId, { codeAttempts: (course.codeAttempts || 0) + 1 });
        throw new UserError('Code de remise incorrect');
      }
    }
    if (status === 'ISSUE') {
      if (!reason) throw new UserError('Indiquez le motif du problème');
      patch.reason = String(reason);
    }

    let updated;
    try {
      updated = await store.update('Course', courseId, patch, { status: course.status, courierId: identity.sub });
    } catch (e) {
      if (e instanceof ConditionFailed) throw new UserError('La course a changé entre-temps, rechargez-la');
      throw e;
    }

    if (status === 'COMPLETED' && course.paymentMode === 'CARD' && course.paymentIntentId) {
      try {
        await stripe.capture(course.paymentIntentId);
        updated = await store.update('Course', courseId, { paymentStatus: 'captured' });
      } catch (e) {
        log.error(`Encaissement impossible pour ${course.ref} : ${e.message}`);
        updated = await store.update('Course', courseId, { paymentStatus: 'capture_failed' });
      }
    }
    if (status === 'COMPLETED' || status === 'ISSUE') await releaseCourier(identity.sub);
    await addEvent(updated, status, { message: patch.reason });
    return updated;
  }

  async function cancelCourse(identity, { courseId, reason }) {
    const course = await getCourse(courseId);
    const staff = isStaff(identity);
    if (!staff && course.clientId !== identity.sub) throw new UserError('Course introuvable');
    const allowed = staff ? ADMIN_CANCELLABLE : CLIENT_CANCELLABLE;
    if (!allowed.includes(course.status)) throw new UserError('Cette course ne peut plus être annulée');

    let updated;
    try {
      updated = await store.update('Course', courseId, {
        status: 'CANCELLED',
        reason: reason || (staff ? 'Annulée par Wabap' : 'Annulée par le client'),
        updatedAt: iso(),
      }, { status: course.status });
    } catch (e) {
      if (e instanceof ConditionFailed) throw new UserError('La course a changé entre-temps, rechargez-la');
      throw e;
    }
    if (course.paymentMode === 'CARD' && course.paymentIntentId) {
      try {
        await stripe.cancel(course.paymentIntentId);
        updated = await store.update('Course', courseId, { paymentStatus: 'cancelled' });
      } catch (e) {
        log.error(`Annulation du paiement impossible pour ${course.ref} : ${e.message}`);
      }
    }
    await releaseCourier(course.courierId);
    await addEvent(updated, 'CANCELLED', { message: updated.reason });
    return updated;
  }

  async function rateCourse(identity, { courseId, stars, comment }) {
    const course = await getCourse(courseId);
    if (course.clientId !== identity.sub) throw new UserError('Course introuvable');
    if (course.status !== 'COMPLETED') throw new UserError('Seules les courses livrées peuvent être notées');
    const n = Number(stars);
    if (!Number.isInteger(n) || n < 1 || n > 5) throw new UserError('La note doit être comprise entre 1 et 5');
    let updated;
    try {
      updated = await store.update('Course', courseId, {
        ratingStars: n, ratingComment: comment ? String(comment) : null, updatedAt: iso(),
      }, { ratingStars: null });
    } catch (e) {
      if (e instanceof ConditionFailed) throw new UserError('Cette course a déjà été notée');
      throw e;
    }
    const profile = course.courierId && await store.get('CourierProfile', course.courierId);
    if (profile) {
      const count = (profile.ratingsCount || 0) + 1;
      const rating = round2(((profile.ratingsCount ? profile.rating : 0) * (count - 1) + n) / count);
      await store.update('CourierProfile', profile.id, { rating, ratingsCount: count, updatedAt: iso() });
    }
    return updated;
  }

  async function setCourierAvailability(identity, { online, vehicle }) {
    requireCourier(identity);
    if (vehicle && !VEHICLES.includes(vehicle)) throw new UserError('Véhicule invalide');
    const at = iso();
    let profile = await store.get('CourierProfile', identity.sub);
    if (!profile) {
      if (!vehicle) throw new UserError('Choisissez votre véhicule');
      profile = {
        __typename: 'CourierProfile',
        id: identity.sub,
        courierId: identity.sub,
        name: identity.name || identity.email || null,
        phone: identity.phone || null,
        vehicle,
        online: false,
        rating: 5,
        ratingsCount: 0,
        activeCourseId: null,
        createdAt: at,
        updatedAt: at,
      };
      await store.put('CourierProfile', profile);
    }
    return store.update('CourierProfile', identity.sub, {
      online: Boolean(online),
      ...(vehicle ? { vehicle } : {}),
      lastSeen: at,
      updatedAt: at,
    });
  }

  async function updateCourierPosition(identity, { latitude, longitude }) {
    requireCourier(identity);
    const lat = Number(latitude), lng = Number(longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
      throw new UserError('Position invalide');
    }
    const at = iso();
    let profile;
    try {
      profile = await store.update('CourierProfile', identity.sub, {
        latitude: lat, longitude: lng, zone: geohash.encode(lat, lng, 5), lastSeen: at,
      });
    } catch (e) {
      if (e instanceof ConditionFailed) throw new UserError('Passez en ligne une première fois pour créer votre profil');
      throw e;
    }
    return { courseId: profile.activeCourseId || null, courierId: identity.sub, latitude: lat, longitude: lng, at };
  }

  async function availableCourses(identity) {
    requireCourier(identity);
    const profile = await store.get('CourierProfile', identity.sub);
    if (!profile || !profile.online || !profile.zone) return [];
    const cells = geohash.neighborhood(profile.zone);
    const lists = await Promise.all(cells.map((zone) =>
      store.query('Course', 'byZone', 'zone', zone, { sortKey: 'status', sortValue: 'PENDING' })));
    const here = { latitude: profile.latitude, longitude: profile.longitude };
    return lists.flat()
      .filter((c) => c.status === 'PENDING' && c.vehicle === profile.vehicle)
      .map((c) => ({ ...c, distanceToPickupKm: round2(haversineKm(here, c.pickup)) }))
      .filter((c) => c.distanceToPickupKm <= DISPATCH_RADIUS_KM)
      .sort((a, b) => a.distanceToPickupKm - b.distanceToPickupKm);
  }

  async function courierEarnings(identity) {
    requireCourier(identity);
    const courses = (await store.query('Course', 'byCourier', 'courierId', identity.sub, { limit: 500 }))
      .filter((c) => c.status === 'COMPLETED');
    const today = new Date(now()); today.setHours(0, 0, 0, 0);
    const week = new Date(today); week.setDate(week.getDate() - ((week.getDay() + 6) % 7));
    const sum = (list) => ({ count: list.length, amount: round2(list.reduce((s, c) => s + c.courierEarning, 0)) });
    const profile = await store.get('CourierProfile', identity.sub);
    return {
      today: sum(courses.filter((c) => new Date(c.updatedAt) >= today)),
      week: sum(courses.filter((c) => new Date(c.updatedAt) >= week)),
      total: { ...sum(courses), distanceKm: round2(courses.reduce((s, c) => s + c.distanceKm, 0)) },
      rating: profile ? profile.rating : 5,
      recent: courses.slice(0, 20).map((c) => ({
        courseId: c.id, ref: c.ref, amount: c.courierEarning, distanceKm: c.distanceKm,
        at: c.updatedAt, dropoffAddress: c.dropoff.address,
      })),
    };
  }

  async function quoteForClient(identity, args) {
    const { tarif, pickup, dropoff, ...q } = await quoteCourse(identity, args);
    return q;
  }

  return {
    quoteCourse: quoteForClient,
    createCourse,
    confirmCoursePayment,
    acceptCourse,
    updateCourseStep,
    cancelCourse,
    rateCourse,
    setCourierAvailability,
    updateCourierPosition,
    availableCourses,
    courierEarnings,
  };
}

module.exports = { createService, UserError, COURIER_FLOW, MAX_CODE_ATTEMPTS };

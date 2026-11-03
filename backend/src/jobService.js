// Logique métier des courses (création, transitions de statut, diffusion temps réel).
const crypto = require('crypto');
const { quote, validPoint, SIZES, URGENCY, VEHICLES, COURIER_SHARE, round2, haversineKm } = require('./pricing');

// Machine à états d'une course
const FLOW = {
  pending:    ['assigned', 'cancelled'],
  assigned:   ['picking_up', 'cancelled'],
  picking_up: ['picked_up', 'cancelled'],
  picked_up:  ['delivering'],
  delivering: ['delivered', 'failed'],
  delivered:  [],
  failed:     [],
  cancelled:  [],
};
const ACTIVE = ['assigned', 'picking_up', 'picked_up', 'delivering'];
const DISPATCH_RADIUS_KM = 15;

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

function cleanStop(s = {}) {
  return {
    address: String(s.address || '').trim(),
    lat: Number(s.lat),
    lng: Number(s.lng),
    contactName: String(s.contactName || '').trim(),
    phone: String(s.phone || '').trim(),
    instructions: String(s.instructions || '').trim(),
  };
}

function createJobService(db, io) {
  let counter = db.jobs.all().length;

  function emitJob(job) {
    if (!io) return;
    const payload = { job: viewFor(job, null) };
    io.to(`job:${job.id}`).to(`user:${job.clientId}`).to('admins').emit('job:updated', payload);
    if (job.courierId) io.to(`user:${job.courierId}`).emit('job:updated', payload);
  }

  function dispatch(job) {
    if (!io) return;
    for (const c of eligibleCouriers(job)) {
      io.to(`user:${c.id}`).emit('job:new', { job: viewFor(job, c) });
    }
  }

  function eligibleCouriers(job) {
    return db.users.find((u) =>
      u.role === 'courier' && u.online && u.vehicle === job.vehicle &&
      !db.jobs.findOne((j) => j.courierId === u.id && ACTIVE.includes(j.status)) &&
      (!u.location || haversineKm(u.location, job.pickup) <= DISPATCH_RADIUS_KM));
  }

  // Le code de remise n'est visible que par le client (et l'admin).
  function viewFor(job, user) {
    const courier = job.courierId ? db.users.byId(job.courierId) : null;
    const v = {
      ...job,
      courier: courier ? {
        id: courier.id, name: courier.name, phone: courier.phone, vehicle: courier.vehicle,
        rating: courier.rating, location: courier.location,
      } : null,
    };
    if (!user || (user.role !== 'admin' && user.id !== job.clientId)) delete v.deliveryCode;
    if (user && user.role === 'courier') delete v.price;
    return v;
  }

  function create(client, body) {
    const pickup = cleanStop(body.pickup);
    const dropoff = cleanStop(body.dropoff);
    const packageSize = body.packageSize || 'S';
    const urgency = body.urgency || 'standard';
    if (!validPoint(pickup) || !validPoint(dropoff)) throw new HttpError(400, 'Adresses de retrait et de livraison requises (lat/lng)');
    if (!pickup.address || !dropoff.address) throw new HttpError(400, 'Libellé d’adresse requis');
    if (!SIZES.includes(packageSize)) throw new HttpError(400, 'Taille de colis invalide');
    if (!URGENCY[urgency]) throw new HttpError(400, 'Urgence invalide');

    const q = quote({ pickup, dropoff, packageSize, urgency });
    const option = body.vehicle ? q.options.find((o) => o.vehicle === body.vehicle) : q.options[0];
    if (!option) throw new HttpError(422, 'Aucun véhicule disponible pour cette distance / taille');

    const now = new Date().toISOString();
    counter += 1;
    const job = db.jobs.insert({
      id: crypto.randomUUID(),
      ref: `LG-${String(counter).padStart(6, '0')}`,
      clientId: client.id,
      clientName: client.name,
      courierId: null,
      pickup, dropoff,
      packageSize, urgency,
      packageDescription: String(body.packageDescription || '').trim(),
      vehicle: option.vehicle,
      distanceKm: q.distanceKm,
      etaMinutes: option.etaMinutes,
      price: option.price,
      courierEarning: round2(option.price.ht * COURIER_SHARE),
      deliveryCode: String(crypto.randomInt(0, 10000)).padStart(4, '0'),
      status: 'pending',
      history: [{ status: 'pending', at: now }],
      rating: null,
      createdAt: now,
      updatedAt: now,
    });
    dispatch(job);
    emitJob(job);
    return job;
  }

  function transition(job, status, extra = {}) {
    if (!FLOW[job.status]?.includes(status)) {
      throw new HttpError(409, `Transition impossible : ${job.status} → ${status}`);
    }
    const now = new Date().toISOString();
    const updated = db.jobs.update(job.id, (j) => ({
      ...extra,
      status,
      updatedAt: now,
      history: [...j.history, { status, at: now, ...(extra.reason ? { reason: extra.reason } : {}) }],
    }));
    emitJob(updated);
    return updated;
  }

  function accept(courier, jobId) {
    const job = db.jobs.byId(jobId);
    if (!job) throw new HttpError(404, 'Course introuvable');
    if (job.status !== 'pending') throw new HttpError(409, 'Course déjà attribuée');
    if (job.vehicle !== courier.vehicle) throw new HttpError(403, 'Véhicule non adapté');
    if (db.jobs.findOne((j) => j.courierId === courier.id && ACTIVE.includes(j.status))) {
      throw new HttpError(409, 'Vous avez déjà une course en cours');
    }
    const updated = transition(job, 'assigned', { courierId: courier.id });
    io?.to('couriers').emit('job:taken', { jobId: job.id });
    return updated;
  }

  function courierUpdate(courier, jobId, { status, code, reason }) {
    const job = db.jobs.byId(jobId);
    if (!job || job.courierId !== courier.id) throw new HttpError(404, 'Course introuvable');
    if (status === 'delivered' && String(code || '') !== job.deliveryCode) {
      throw new HttpError(400, 'Code de remise incorrect');
    }
    if (status === 'failed' && !reason) throw new HttpError(400, 'Motif d’échec requis');
    if (status === 'cancelled') throw new HttpError(403, 'Un coursier ne peut pas annuler, contactez le support');
    return transition(job, status, reason ? { reason } : {});
  }

  function cancel(user, jobId, reason = 'Annulée par le client') {
    const job = db.jobs.byId(jobId);
    if (!job) throw new HttpError(404, 'Course introuvable');
    if (user.role !== 'admin' && job.clientId !== user.id) throw new HttpError(404, 'Course introuvable');
    const updated = transition(job, 'cancelled', { reason });
    if (job.status === 'pending') io?.to('couriers').emit('job:taken', { jobId: job.id });
    return updated;
  }

  function rate(user, jobId, { stars, comment = '' }) {
    const job = db.jobs.byId(jobId);
    if (!job || job.clientId !== user.id) throw new HttpError(404, 'Course introuvable');
    if (job.status !== 'delivered') throw new HttpError(409, 'Seules les courses livrées peuvent être notées');
    if (job.rating) throw new HttpError(409, 'Course déjà notée');
    const n = Number(stars);
    if (!Number.isInteger(n) || n < 1 || n > 5) throw new HttpError(400, 'Note entre 1 et 5');
    const courier = db.users.byId(job.courierId);
    if (courier) {
      const count = (courier.ratingsCount || 0) + 1;
      db.users.update(courier.id, {
        ratingsCount: count,
        rating: round2(((courier.rating || 5) * (count - 1) + n) / count),
      });
    }
    return db.jobs.update(job.id, { rating: { stars: n, comment: String(comment) } });
  }

  function available(courier) {
    return db.jobs
      .find((j) => j.status === 'pending' && j.vehicle === courier.vehicle &&
        (!courier.location || haversineKm(courier.location, j.pickup) <= DISPATCH_RADIUS_KM))
      .map((j) => ({
        ...viewFor(j, courier),
        distanceToPickupKm: courier.location ? round2(haversineKm(courier.location, j.pickup)) : null,
      }))
      .sort((a, b) => (a.distanceToPickupKm ?? 0) - (b.distanceToPickupKm ?? 0));
  }

  function updateCourierLocation(courier, lat, lng) {
    const location = { lat, lng, at: new Date().toISOString() };
    db.users.update(courier.id, { location });
    const active = db.jobs.findOne((j) => j.courierId === courier.id && ACTIVE.includes(j.status));
    if (active && io) {
      io.to(`job:${active.id}`).to(`user:${active.clientId}`).to('admins')
        .emit('courier:location', { jobId: active.id, location });
    }
    return location;
  }

  return { create, accept, courierUpdate, cancel, rate, available, viewFor, updateCourierLocation, eligibleCouriers, ACTIVE };
}

module.exports = { createJobService, HttpError, FLOW, ACTIVE, VEHICLES };

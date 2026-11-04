// Courses ponctuelles (particuliers et pros occasionnels), spec §11 et §11 bis.
// Devis → paiement Stripe avant prise en charge → demande prête à planifier → insertion en tournée
// par le dispatcher → suivi par étapes. Remboursement si annulation ou échec.
const crypto = require('crypto');
const { priceCourse, gridAt, parseGrid, QuoteError } = require('./pricing');
const { roadKm, round2 } = require('./geo');
const { UserError, isStaff, customerIdFor } = require('./orders');

const CANCELLABLE = ['AWAITING_PAYMENT', 'CREATED', 'TO_FIX', 'PLANNED'];

function createCourses(ctx, orders, tours) {
  const { store, stripe } = ctx;
  const tzOffsetMin = ctx.config?.tzOffsetMinutes ?? -240; // Martinique / Guadeloupe : UTC−4
  const now = () => (ctx.now ? ctx.now() : new Date());
  const iso = () => now().toISOString();
  const system = { sub: 'systeme', groups: ['wabap'] };

  async function currentGrid() {
    const grids = await store.query('PriceGrid', 'byKind', 'kind', 'COURSE');
    return gridAt(grids, iso());
  }

  async function km(a, b) {
    if (ctx.router) {
      try { return await ctx.router.km(a, b); } catch (e) { ctx.log?.warn?.(`Itinéraire indisponible : ${e.message}`); }
    }
    return roadKm(a, b);
  }

  async function promoFor(code) {
    if (!code) return null;
    const p = await store.get('PromoCode', String(code).trim().toUpperCase());
    if (!p || !p.active || (p.validUntil && p.validUntil < iso())) throw new UserError('Code promo invalide ou expiré');
    return p;
  }

  // Date limite de livraison : fin de journée locale J+n
  function deadlineFor(maxDays) {
    const local = new Date(now().getTime() + tzOffsetMin * 60000);
    local.setUTCDate(local.getUTCDate() + Number(maxDays));
    local.setUTCHours(23, 59, 0, 0);
    return new Date(local.getTime() - tzOffsetMin * 60000).toISOString();
  }

  async function quote(identity, input) {
    const anomalies = [];
    const pickup = await orders.normalizePoint({ address: input.pickup?.address, name: input.pickup?.name, phone: input.pickup?.phone, instructions: input.pickup?.instructions }, 'pickup', anomalies);
    const delivery = await orders.normalizePoint({ address: input.delivery?.address, name: input.delivery?.name, phone: input.delivery?.phone, instructions: input.delivery?.instructions }, 'delivery', anomalies);
    const blocking = anomalies.filter((a) => ['MISSING_ADDRESS', 'ADDRESS_NOT_FOUND'].includes(a.code));
    if (blocking.length) throw new UserError(blocking.map((a) => a.message).join(' ; '));
    const grid = await currentGrid();
    const distance = await km(pickup.address, delivery.address);
    try {
      const price = priceCourse(grid, distance, input, await promoFor(input.promoCode));
      return { pickup, delivery, price, grid, anomalies, deadlineAt: deadlineFor(input.maxDays) };
    } catch (e) {
      if (e instanceof QuoteError) throw new UserError(e.message);
      throw e;
    }
  }

  async function create(identity, input) {
    const q = await quote(identity, input);
    const contactIssues = q.anomalies.filter((a) => a.code === 'INVALID_PHONE' || a.code === 'INVALID_EMAIL');
    if (contactIssues.length) throw new UserError(contactIssues.map((a) => a.message).join(' ; '));
    if (!q.delivery.contact.name) throw new UserError('Indiquez le nom du destinataire');

    const cid = customerIdFor(identity);
    const customer = await store.get('Customer', cid);
    const onAccount = customer?.billingMode === 'ACCOUNT';
    const order = await orders.ingest(identity, {
      source: 'CLIENT_APP',
      record: {
        pickupAddress: q.pickup.address, pickupName: q.pickup.contact.name, pickupPhone: q.pickup.contact.phone, pickupInstructions: q.pickup.instructions,
        deliveryAddress: q.delivery.address, deliveryName: q.delivery.contact.name, deliveryPhone: q.delivery.contact.phone, instructions: q.delivery.instructions,
        parcelCount: 1, size: input.size, weightKg: input.weightKg, deadlineAt: q.deadlineAt, hardConstraint: true,
        proofProfileId: input.options?.reinforcedProof ? q.grid.options.reinforcedProofProfileId || q.grid.proofProfileId : q.grid.proofProfileId,
      },
    });
    if (order.status === 'TO_FIX') throw new UserError(order.anomalies.map((a) => a.message).join(' ; '));

    const patch = {
      maxDays: Number(input.maxDays),
      price: JSON.stringify(q.price), // figé : une course payée garde son prix
      priceTotal: q.price.total,
      billingMode: onAccount ? 'ACCOUNT' : 'PER_ORDER',
      updatedAt: iso(),
    };
    let clientSecret = null;
    if (!onAccount) {
      const pi = await stripe.createPayment({ amount: q.price.total, orderId: order.id, ref: order.ref, email: identity.email });
      Object.assign(patch, { status: 'AWAITING_PAYMENT', paymentIntentId: pi.id, paymentStatus: 'awaiting' });
      clientSecret = pi.client_secret;
    }
    const updated = await store.update('Order', order.id, patch);

    // Code de confirmation si le profil de preuve l'exige : seul le donneur d'ordre le reçoit
    let otpCode = null;
    const profile = updated.proofProfileId ? await store.get('ProofProfile', updated.proofProfileId) : null;
    if (profile?.delivery?.otp) {
      otpCode = String(crypto.randomInt(0, 10000)).padStart(4, '0');
      await store.put('OrderSecret', { __typename: 'OrderSecret', id: order.id, customerId: cid, ownerSub: updated.ownerSub, otpCode, createdAt: iso(), updatedAt: iso() });
    }
    return { order: updated, paymentClientSecret: clientSecret, otpCode };
  }

  async function getOwn(identity, orderId) {
    const order = await store.get('Order', orderId);
    if (!order || (!isStaff(identity) && order.customerId !== customerIdFor(identity))) throw new UserError('Demande introuvable');
    return order;
  }

  // Après le formulaire de paiement : la demande devient prête à planifier
  async function confirmPayment(identity, { orderId }) {
    const order = await getOwn(identity, orderId);
    if (order.status !== 'AWAITING_PAYMENT') return order;
    const pi = await stripe.retrieve(order.paymentIntentId);
    if (pi.status !== 'succeeded') throw new UserError('Le paiement n’a pas abouti');
    return store.update('Order', orderId, { status: 'CREATED', paymentStatus: 'paid', paidAt: iso(), updatedAt: iso() }, { status: 'AWAITING_PAYMENT' });
  }

  async function refund(order, reason, amount) {
    if (order.billingMode !== 'PER_ORDER' || !['paid', 'partially_refunded'].includes(order.paymentStatus)) return order;
    const refunded = round2((order.refundedAmount || 0) + (amount ?? order.priceTotal - (order.refundedAmount || 0)));
    if (refunded > order.priceTotal + 0.001) throw new UserError('Le remboursement dépasse le montant payé');
    await stripe.refund(order.paymentIntentId, { amount, reason, key: `refund-${order.id}-${refunded}` });
    return store.update('Order', order.id, {
      refundedAmount: refunded,
      paymentStatus: refunded >= order.priceTotal ? 'refunded' : 'partially_refunded',
      refunds: [...(order.refunds || []), { at: iso(), amount: amount ?? round2(order.priceTotal - (order.refundedAmount || 0)), reason }],
      updatedAt: iso(),
    });
  }

  async function cancel(identity, { orderId, reason }) {
    const order = await getOwn(identity, orderId);
    if (!CANCELLABLE.includes(order.status)) throw new UserError('Le colis est déjà pris en charge : la demande ne peut plus être annulée');
    const parcels = await orders.parcelsOf(orderId);
    if (parcels.some((p) => p.status !== 'AWAITING_PICKUP')) throw new UserError('Le colis est déjà collecté');
    const motive = reason || (isStaff(identity) ? 'Annulée par Wabap' : 'Annulée par le client');
    if (order.status === 'PLANNED' && order.tourId) await tours.removeOrder(system, { tourId: order.tourId, orderId, reason: motive });
    let updated = await store.update('Order', orderId, { status: 'CANCELLED', cancelReason: motive, cancelledAt: iso(), updatedAt: iso() });
    for (const p of parcels) await orders.addEvent(p, 'CANCELLED', { actor: identity.sub, comment: motive });
    updated = await refund(updated, motive);
    return updated;
  }

  // Échec de livraison d'une course payée : remboursement (spec §11 bis)
  async function onOrderStatus(order, { failedReason } = {}) {
    if (order.status === 'PARTIALLY_FAILED' && order.billingMode === 'PER_ORDER') {
      await refund(order, `Échec de livraison : ${failedReason || 'motif non précisé'}`);
    }
  }

  // Geste commercial : remboursement partiel décidé par Wabap
  async function gesture(identity, { orderId, amount, reason }) {
    if (!isStaff(identity)) throw new UserError('Réservé aux équipes Wabap');
    if (!reason) throw new UserError('Indiquez le motif du geste commercial');
    if (!(amount > 0)) throw new UserError('Montant invalide');
    return refund(await getOwn(identity, orderId), `Geste commercial : ${reason}`, round2(amount));
  }

  // Suivi par étapes pour le client (spec §11) : pas de carte, pas de commentaire interne
  async function clientView(identity, { orderId }) {
    const order = await getOwn(identity, orderId);
    const parcels = await orders.parcelsOf(orderId);
    const events = (await Promise.all(parcels.map((p) => orders.history(p.id)))).flat().sort((a, b) => a.at.localeCompare(b.at));
    const first = (type) => events.find((e) => e.type === type);
    const failed = first('FAILED');
    const steps = [
      { key: 'PAID', label: order.billingMode === 'ACCOUNT' ? 'Demande enregistrée' : 'Demande payée', at: order.paidAt || (order.billingMode === 'ACCOUNT' ? order.createdAt : null) },
      { key: 'PLANNED', label: 'Planifiée', at: first('ASSIGNED_TO_TOUR')?.at || null },
      { key: 'PICKED_UP', label: 'Colis collecté', at: first('PICKED_UP')?.at || null },
      { key: 'OUT_FOR_DELIVERY', label: 'En cours de livraison', at: first('PICKED_UP')?.at || null },
      failed
        ? { key: 'FAILED', label: 'Échec de livraison', at: failed.at, detail: failed.comment || null }
        : { key: 'DELIVERED', label: 'Livré', at: first('DELIVERED')?.at || null },
    ];
    if (order.status === 'CANCELLED') steps.push({ key: 'CANCELLED', label: 'Annulée', at: order.cancelledAt, detail: order.cancelReason });
    const proofEvents = events.filter((e) => ['PICKED_UP', 'DELIVERED', 'FAILED'].includes(e.type)).map((e) => {
      const pr = e.proofs ? JSON.parse(e.proofs) : {};
      return { type: e.type, at: e.at, comment: e.comment, photoKeys: pr.photoKeys || [], signerName: pr.signerName || null, signatureKey: pr.signatureKey || null };
    });
    const secret = await store.get('OrderSecret', orderId);
    return {
      order: { ...order, rawInput: undefined, anomalies: undefined },
      steps,
      currentStep: [...steps].reverse().find((s) => s.at)?.key || null,
      proofs: proofEvents,
      price: order.price ? JSON.parse(order.price) : null,
      otpCode: secret ? secret.otpCode : null,
    };
  }

  return { quote, create, confirmPayment, cancel, gesture, onOrderStatus, clientView, deadlineFor, currentGrid };
}

module.exports = { createCourses };

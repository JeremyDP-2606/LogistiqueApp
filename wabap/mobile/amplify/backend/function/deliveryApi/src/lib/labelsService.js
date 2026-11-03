// Génération et envoi des étiquettes (spec §4.2, §4.3), statistiques des commentaires (§5.4).
const { renderLabels } = require('./labelPdf');
const { UserError, isStaff, customerIdFor } = require('./orders');

const OPEN_TOUR = ['DRAFT', 'PLANNED', 'ASSIGNED', 'ACCEPTED'];

function createLabels(ctx, orders) {
  const { store } = ctx;
  const iso = () => (ctx.now ? ctx.now() : new Date()).toISOString();
  const tz = ctx.config?.tzOffsetMinutes ?? -240;

  async function labelData(parcel, tour) {
    const customer = await store.get('Customer', parcel.customerId);
    const order = parcel.orderId ? await store.get('Order', parcel.orderId) : null;
    return {
      code: parcel.code,
      parcelId: parcel.id,
      customerName: customer?.name || order?.customerName || '',
      reserved: parcel.labelStatus === 'RESERVED',
      index: parcel.index,
      total: parcel.total,
      orderRef: order?.ref,
      tourRef: tour?.ref,
      recipient: order ? { name: order.delivery.contact.name, phone: order.delivery.contact.phone, address: order.delivery.address?.formatted } : null,
      deadlineAt: order?.deadlineAt && order.hardConstraint ? order.deadlineAt : null,
      fragile: Boolean(order?.fragile),
      instructions: order?.delivery.instructions,
    };
  }

  async function pdfFor(parcels, tour, name) {
    const bytes = await renderLabels(await Promise.all(parcels.map((p) => labelData(p, tour))), { tzOffsetMinutes: tz });
    return ctx.files.put(`etiquettes/${name}.pdf`, bytes, 'application/pdf');
  }

  // Génération manuelle : une demande, ou une tournée (avec étiquettes en réserve en plus si demandé)
  async function generate(identity, { tourId, orderId, customerId, extraCount = 0 }) {
    const staff = isStaff(identity);
    const own = customerIdFor(identity);
    let parcels = [];
    let tour = null;
    if (orderId) {
      const order = await store.get('Order', orderId);
      if (!order || (!staff && order.customerId !== own)) throw new UserError('Demande introuvable');
      parcels = (await orders.parcelsOf(orderId)).filter((p) => p.labelStatus === 'ACTIVE');
    } else if (tourId) {
      tour = await store.get('Tour', tourId);
      if (!tour) throw new UserError('Tournée introuvable');
      const cid = staff ? customerId || null : own; // cloisonnement : un client n'a que ses étiquettes
      if (!staff && !tour.customerIds.includes(own)) throw new UserError('Tournée introuvable');
      parcels = (await store.query('Parcel', 'byTour', 'tourId', tourId))
        .filter((p) => (!cid || p.customerId === cid) && ['ACTIVE', 'RESERVED'].includes(p.labelStatus) && p.status === 'AWAITING_PICKUP');
      if (extraCount > 0) {
        if (!cid) throw new UserError('Précisez le client des étiquettes en réserve');
        if (!OPEN_TOUR.includes(tour.status)) throw new UserError('Tournée déjà démarrée');
        if (extraCount > 1000) throw new UserError('1000 étiquettes en réserve au maximum par génération');
        const customer = await store.get('Customer', cid);
        parcels.push(...await orders.createParcels({ id: null, customerId: cid, size: customer?.defaultSize || 'S', weightKg: null }, extraCount, { reservedForTour: tourId }));
      }
    } else {
      throw new UserError('Précisez une demande ou une tournée');
    }
    if (!parcels.length) throw new UserError('Aucune étiquette à générer');
    parcels.sort((a, b) => (a.orderId || 'zzz').localeCompare(b.orderId || 'zzz') || a.index - b.index);
    const file = await pdfFor(parcels, tour, `${tour ? tour.ref : orderId}-${Date.now()}`);
    for (const p of parcels.filter((x) => x.labelStatus === 'ACTIVE')) {
      await orders.addEvent(p, 'LABEL_GENERATED', { actor: identity.sub });
    }
    return { ...file, count: parcels.length, reservedCount: parcels.filter((p) => p.labelStatus === 'RESERVED').length };
  }

  // Envoi automatique aux clients B2B qui l'ont activé (tâche planifiée).
  // Chaque client ne reçoit que ses propres étiquettes ; un nouvel envoi ne contient que les nouvelles.
  async function sendDue() {
    const nowMs = (ctx.now ? ctx.now() : new Date()).getTime();
    const sent = [];
    for (const status of OPEN_TOUR) {
      for (const tour of await store.query('Tour', 'byStatus', 'status', status)) {
        for (const cid of tour.customerIds || []) {
          const customer = await store.get('Customer', cid);
          const opt = customer?.labelEmail;
          if (!opt?.enabled || !(opt.emails || []).length || customer.billingMode === 'PER_ORDER') continue;
          const lead = tour.labelLeadHours?.[cid] ?? opt.leadHours ?? 24;
          if (new Date(tour.startTime).getTime() - lead * 3600000 > nowMs) continue;
          const already = new Set((tour.labelSends?.[cid] || []).flatMap((s) => s.parcelIds));
          const fresh = (await store.query('Parcel', 'byTour', 'tourId', tour.id))
            .filter((p) => p.customerId === cid && p.labelStatus === 'ACTIVE' && !already.has(p.id));
          if (!fresh.length) continue;
          const file = await pdfFor(fresh, tour, `${tour.ref}-${cid}-${nowMs}`);
          const complement = already.size > 0;
          await ctx.mailer.send({
            to: opt.emails,
            subject: `${complement ? 'Étiquettes complémentaires' : 'Étiquettes'} – tournée du ${tour.date} (${fresh.length} colis)`,
            text: `Bonjour,\n\nVeuillez trouver ci-joint ${complement ? 'les étiquettes des colis ajoutés à' : 'les étiquettes de vos colis pour'} la tournée ${tour.ref} du ${tour.date}.\nCollez une étiquette par colis avant le passage du livreur.\n\nL'équipe Wabap`,
            attachments: [{ filename: `etiquettes-${tour.ref}.pdf`, key: file.key }],
          });
          const sends = { ...(tour.labelSends || {}) };
          sends[cid] = [...(sends[cid] || []), { at: iso(), parcelIds: fresh.map((p) => p.id), to: opt.emails }];
          await store.update('Tour', tour.id, { labelSends: sends });
          tour.labelSends = sends;
          for (const p of fresh) await orders.addEvent(p, 'LABEL_SENT', { actor: 'systeme', comment: `Envoyées à ${opt.emails.join(', ')}` });
          sent.push({ tourId: tour.id, customerId: cid, count: fresh.length, complement });
        }
      }
    }
    return sent;
  }

  // Statistiques des commentaires prédéfinis, par motif et par code postal (spec §5.4)
  async function commentStats(identity, { from, to }) {
    if (!isStaff(identity)) throw new UserError('Réservé aux équipes Wabap');
    const presets = await store.query('CommentPreset', 'byActive', 'active', 'yes');
    const byLabel = new Map(presets.map((p) => [p.label, p]));
    const counts = new Map();
    for (let d = new Date(`${from}T00:00:00Z`); d <= new Date(`${to}T00:00:00Z`); d.setUTCDate(d.getUTCDate() + 1)) {
      const events = await store.query('ParcelEvent', 'byDay', 'day', d.toISOString().slice(0, 10));
      for (const e of events) {
        const text = [e.comment, e.internalComment].filter(Boolean).join(' — ');
        for (const [label, preset] of byLabel) {
          if (!text.includes(label)) continue;
          const stop = e.stopId ? await store.get('Stop', e.stopId) : null;
          const key = `${preset.id}|${stop?.address?.postalCode || '—'}`;
          counts.set(key, { presetId: preset.id, label, kind: preset.kind, postalCode: stop?.address?.postalCode || null, count: (counts.get(key)?.count || 0) + 1 });
        }
      }
    }
    return [...counts.values()].sort((a, b) => b.count - a.count);
  }

  return { generate, sendDue, commentStats };
}

module.exports = { createLabels };

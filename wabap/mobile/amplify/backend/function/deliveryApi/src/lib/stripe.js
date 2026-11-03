// Client Stripe minimal (API REST, sans dépendance).
// Spec §11 bis : paiement avant prise en charge (encaissement immédiat),
// remboursement si annulation ou échec, geste commercial = remboursement partiel.
function form(obj, prefix = '') {
  const parts = [];
  for (const [k, v] of Object.entries(obj)) {
    if (v === undefined || v === null) continue;
    const key = prefix ? `${prefix}[${k}]` : k;
    if (typeof v === 'object') parts.push(form(v, key));
    else parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(v)}`);
  }
  return parts.filter(Boolean).join('&');
}

function createStripe({ getKey, fetchImpl = fetch }) {
  async function call(method, path, body, idempotencyKey) {
    const key = await getKey();
    const res = await fetchImpl(`https://api.stripe.com/v1/${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        ...(idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {}),
      },
      body: body ? form(body) : undefined,
    });
    const data = await res.json();
    if (!res.ok) throw new Error(`Stripe : ${(data.error && data.error.message) || res.status}`);
    return data;
  }

  return {
    // amount en euros, converti en centimes ; encaissé dès la confirmation par le client
    createPayment: ({ amount, orderId, ref, email }) => call('POST', 'payment_intents', {
      amount: Math.round(amount * 100),
      currency: 'eur',
      automatic_payment_methods: { enabled: 'true' },
      description: `Course Wabap ${ref}`,
      receipt_email: email,
      metadata: { orderId, ref },
    }, `pay-${orderId}`),
    retrieve: (id) => call('GET', `payment_intents/${id}`),
    // amount facultatif (euros) : remboursement partiel ; sinon total
    refund: (paymentIntentId, { amount, reason, key }) => call('POST', 'refunds', {
      payment_intent: paymentIntentId,
      amount: amount !== undefined ? Math.round(amount * 100) : undefined,
      metadata: { motif: reason },
    }, key),
  };
}

module.exports = { createStripe, form };

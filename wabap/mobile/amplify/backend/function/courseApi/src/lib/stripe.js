// Client Stripe minimal (API REST, sans dépendance).
// Le paiement d'une course : autorisation à la commande (capture_method=manual),
// encaissement à la livraison, annulation de l'autorisation si la course est annulée.
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
    // amount en euros, converti en centimes
    createAuthorization: ({ amount, courseId, ref, email }) => call('POST', 'payment_intents', {
      amount: Math.round(amount * 100),
      currency: 'eur',
      capture_method: 'manual',
      automatic_payment_methods: { enabled: 'true' },
      description: `Course Wabap ${ref}`,
      receipt_email: email,
      metadata: { courseId, ref },
    }, `create-${courseId}`),
    retrieve: (id) => call('GET', `payment_intents/${id}`),
    capture: (id) => call('POST', `payment_intents/${id}/capture`, {}, `capture-${id}`),
    cancel: (id) => call('POST', `payment_intents/${id}/cancel`, {}, `cancel-${id}`),
  };
}

module.exports = { createStripe, form };

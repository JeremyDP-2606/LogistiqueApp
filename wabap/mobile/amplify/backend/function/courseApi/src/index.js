/* Amplify Params - DO NOT EDIT
	ENV
	REGION
Amplify Params - DO NOT EDIT */
// Résolveur AppSync (@function) de toutes les opérations des courses à la demande.
const { createService, UserError } = require('./lib/service');
const { createDynamoStore } = require('./lib/store');
const { createStripe } = require('./lib/stripe');
const { createGoogle } = require('./lib/google');
const { getSecret } = require('./secrets');

let service;
function getService() {
  if (!service) {
    if (!process.env.GRAPHQL_API_ID) throw new Error('GRAPHQL_API_ID manquant (paramètre graphqlApiId de la fonction)');
    service = createService({
      store: createDynamoStore({ apiId: process.env.GRAPHQL_API_ID, env: process.env.ENV, region: process.env.REGION }),
      stripe: createStripe({ getKey: () => getSecret('STRIPE_SECRET_KEY') }),
      google: createGoogle({ getKey: () => getSecret('GOOGLE_MAPS_API_KEY') }),
    });
  }
  return service;
}

function identityFrom(event) {
  const id = event.identity || {};
  const claims = id.claims || {};
  if (!id.sub && !claims.sub) throw new UserError('Authentification requise');
  return {
    sub: id.sub || claims.sub,
    groups: id.groups || claims['cognito:groups'] || [],
    name: claims.name || claims.given_name || null,
    email: claims.email || null,
    phone: claims.phone_number || null,
    clientName: claims['custom:clientName'] || null,
  };
}

async function handle(event, svc) {
  const op = svc[event.fieldName];
  if (!op) throw new Error(`Opération inconnue : ${event.fieldName}`);
  try {
    return await op(identityFrom(event), event.arguments || {});
  } catch (e) {
    if (e instanceof UserError) throw e;
    console.error(`${event.fieldName} :`, e);
    throw new Error('Erreur serveur, réessayez dans un instant');
  }
}

exports.handler = (event) => handle(event, getService());
exports.handle = handle;

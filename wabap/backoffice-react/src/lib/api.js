// Appels à l'API GraphQL Wabap avec le jeton d'identité Cognito.
import { config } from './config';
import { idToken } from './cognito';

export async function gql(query, variables = {}) {
  const token = await idToken();
  if (!token) throw new Error('Session expirée : reconnectez-vous');
  let res;
  try {
    res = await fetch(config.apiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: token },
      body: JSON.stringify({ query, variables }),
    });
  } catch {
    throw new Error('Serveur injoignable : vérifiez votre connexion');
  }
  const body = await res.json().catch(() => ({}));
  if (body.errors?.length) throw new Error(body.errors[0].message || 'Erreur inconnue');
  if (!res.ok) throw new Error(`Erreur ${res.status}`);
  return body.data;
}

export const parseJson = (v) => (typeof v === 'string' ? JSON.parse(v) : v);

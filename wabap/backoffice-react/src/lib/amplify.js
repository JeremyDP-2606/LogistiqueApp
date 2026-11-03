import { Amplify } from 'aws-amplify';
import { generateClient } from 'aws-amplify/api';
import awsExports from '../aws-exports';

// Le back-office ne parle qu'à AppSync avec le jeton Cognito : aucun identifiant AWS n'est nécessaire
// dans le navigateur, on n'utilise donc pas le pool d'identités (moins de droits exposés).
const { aws_cognito_identity_pool_id: _unused, ...config } = awsExports;
Amplify.configure(config);

export const client = generateClient();

// Appel GraphQL ; les erreurs métier de la Lambda sont rédigées pour l'utilisateur
export async function gql(query, variables = {}) {
  try {
    const r = await client.graphql({ query, variables });
    return r.data;
  } catch (e) {
    const msg = e?.errors?.[0]?.message || e?.message || 'Erreur inconnue';
    throw new Error(msg);
  }
}

export const parseJson = (v) => (typeof v === 'string' ? JSON.parse(v) : v);

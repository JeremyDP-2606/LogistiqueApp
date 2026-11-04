// Connexion Cognito (SDK officiel amazon-cognito-identity-js, protocole SRP) : la session est conservée
// dans le stockage local du navigateur et rafraîchie automatiquement.
import { CognitoUserPool, CognitoUser, AuthenticationDetails } from 'amazon-cognito-identity-js';
import { config } from './config';

const pool = new CognitoUserPool({ UserPoolId: config.userPoolId, ClientId: config.clientId });
let pendingChallenge = null; // utilisateur devant choisir un nouveau mot de passe

// Session valide (rafraîchie si besoin) ou null
export function currentSession() {
  const user = pool.getCurrentUser();
  if (!user) return Promise.resolve(null);
  return new Promise((resolve) => {
    user.getSession((err, session) => resolve(err || !session?.isValid() ? null : session));
  });
}

export async function idToken() {
  const s = await currentSession();
  return s ? s.getIdToken().getJwtToken() : null;
}

export function signIn(username, password) {
  const user = new CognitoUser({ Username: username, Pool: pool });
  return new Promise((resolve, reject) => {
    user.authenticateUser(new AuthenticationDetails({ Username: username, Password: password }), {
      onSuccess: () => resolve('OK'),
      onFailure: (e) => reject(new Error(e.message || 'Connexion impossible')),
      newPasswordRequired: () => { pendingChallenge = user; resolve('NEW_PASSWORD'); },
    });
  });
}

export function completeNewPassword(password) {
  if (!pendingChallenge) return Promise.reject(new Error('Aucun changement de mot de passe en attente'));
  return new Promise((resolve, reject) => {
    pendingChallenge.completeNewPasswordChallenge(password, {}, {
      onSuccess: () => { pendingChallenge = null; resolve(); },
      onFailure: (e) => reject(new Error(e.message || 'Mot de passe refusé')),
    });
  });
}

export function signOut() {
  pool.getCurrentUser()?.signOut();
}

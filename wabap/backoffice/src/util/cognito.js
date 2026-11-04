// Session Cognito (SDK officiel amazon-cognito-identity-js) avec les mêmes méthodes que l'objet « Auth »
// utilisé jusqu'ici par le back-office : signIn, completeNewPassword, currentSession,
// currentAuthenticatedUser, signOut.
import { CognitoUserPool, CognitoUser, AuthenticationDetails } from "amazon-cognito-identity-js";
import { config } from "@/config";

const pool = new CognitoUserPool({ UserPoolId: config.userPoolId, ClientId: config.clientId });

function sessionOf(user) {
  return new Promise((resolve, reject) => {
    if (!user) return reject(new Error("The user is not authenticated"));
    user.getSession((err, session) => (err || !session?.isValid() ? reject(err || new Error("Session expirée")) : resolve(session)));
  });
}

export const Auth = {
  signIn(username, password) {
    const user = new CognitoUser({ Username: username, Pool: pool });
    return new Promise((resolve, reject) => {
      user.authenticateUser(new AuthenticationDetails({ Username: username, Password: password }), {
        onSuccess: () => resolve(user),
        onFailure: (e) => reject(e), // e.code : NotAuthorizedException, UserNotFoundException…
        newPasswordRequired: () => { user.challengeName = "NEW_PASSWORD_REQUIRED"; resolve(user); },
      });
    });
  },
  completeNewPassword(user, newPassword) {
    return new Promise((resolve, reject) => {
      user.completeNewPasswordChallenge(newPassword, {}, { onSuccess: resolve, onFailure: reject });
    });
  },
  currentSession() {
    return sessionOf(pool.getCurrentUser());
  },
  async currentAuthenticatedUser() {
    const user = pool.getCurrentUser();
    const session = await sessionOf(user);
    const id = session.getIdToken();
    const access = session.getAccessToken();
    return {
      username: user.getUsername(),
      attributes: id.decodePayload(),
      signInUserSession: {
        idToken: { jwtToken: id.getJwtToken(), payload: id.decodePayload() },
        accessToken: { jwtToken: access.getJwtToken(), payload: access.decodePayload() },
      },
    };
  },
  async signOut() {
    pool.getCurrentUser()?.signOut();
  },
};

export async function idToken() {
  try { return (await Auth.currentSession()).getIdToken().getJwtToken(); } catch { return null; }
}

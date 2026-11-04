// Liste des utilisateurs du groupe Cognito (ancienne fonction listUsers, désormais paginée jusqu'au bout).
function createUsers({ config, client }) {
  async function list() {
    if (!config.userPoolId) throw Object.assign(new Error('COGNITO_USER_POOL_ID manquant'), { status: 501 });
    const { CognitoIdentityProviderClient, ListUsersCommand } = require('@aws-sdk/client-cognito-identity-provider');
    const cognito = client || new CognitoIdentityProviderClient({ region: config.region });
    const users = [];
    let token;
    do {
      const r = await cognito.send(new ListUsersCommand({ UserPoolId: config.userPoolId, Limit: 60, PaginationToken: token }));
      users.push(...r.Users);
      token = r.PaginationToken;
    } while (token);
    return users.map((u) => {
      const attr = Object.fromEntries((u.Attributes || []).map((a) => [a.Name, a.Value]));
      return {
        username: u.Username,
        sub: attr.sub,
        given_name: attr.given_name,
        family_name: attr.family_name,
        client_name: attr['custom:clientName'],
        email: attr.email,
      };
    });
  }
  return { list };
}

module.exports = { createUsers };

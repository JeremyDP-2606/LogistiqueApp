// Administration des utilisateurs Cognito pour le back-office V1 (autrefois faite depuis le navigateur
// avec des identifiants AWS du pool d'identités). Droits vérifiés ici :
//  - équipe Wabap (groupes wabap, admin) : tous les utilisateurs, tous les groupes ;
//  - client (groupe client, attribut custom:clientName) : uniquement les utilisateurs de son compte,
//    groupes « client » et « livreur » seulement, attribut custom:clientName imposé.
const CLIENT_ASSIGNABLE_GROUPS = ['client', 'livreur'];

function createCognitoAdmin({ config, client }) {
  let cognito = client;
  const sdk = () => {
    if (!config.userPoolId) throw Object.assign(new Error('COGNITO_USER_POOL_ID manquant'), { status: 501 });
    const lib = require('@aws-sdk/client-cognito-identity-provider');
    if (!cognito) cognito = new lib.CognitoIdentityProviderClient({ region: config.region });
    return { lib, send: (Cmd, input) => cognito.send(new lib[Cmd]({ UserPoolId: config.userPoolId, ...input })) };
  };
  const attr = (u, name) => (u.Attributes || u.UserAttributes || []).find((a) => a.Name === name)?.Value;
  const forbidden = (msg = 'Accès refusé') => Object.assign(new Error(msg), { status: 403 });
  const isStaff = (id) => id.groups.some((g) => ['wabap', 'admin'].includes(g));
  const clientOf = (id) => id.claims['custom:clientName'] || null;
  const canManage = (id) => isStaff(id) || (id.groups.includes('client') && clientOf(id));

  async function listAll(filter) {
    const { send } = sdk();
    const users = [];
    let token;
    do {
      const r = await send('ListUsersCommand', { Limit: 60, PaginationToken: token, ...(filter ? { Filter: filter } : {}) });
      users.push(...r.Users);
      token = r.PaginationToken;
    } while (token);
    return users;
  }

  async function userByName(username) {
    const { send } = sdk();
    const u = await send('AdminGetUserCommand', { Username: username });
    return { Username: u.Username, Attributes: u.UserAttributes, Enabled: u.Enabled, UserStatus: u.UserStatus, UserCreateDate: u.UserCreateDate, UserLastModifiedDate: u.UserLastModifiedDate };
  }

  async function checkTarget(identity, username) {
    if (isStaff(identity)) return;
    const u = await userByName(username);
    if (attr(u, 'custom:clientName') !== clientOf(identity)) throw forbidden();
  }
  const checkGroup = (identity, group) => {
    if (!isStaff(identity) && !CLIENT_ASSIGNABLE_GROUPS.includes(group)) throw forbidden(`Groupe non autorisé : ${group}`);
  };

  return {
    async list(identity) {
      if (!canManage(identity)) throw forbidden();
      const users = await listAll();
      return isStaff(identity) ? users : users.filter((u) => attr(u, 'custom:clientName') === clientOf(identity));
    },
    async bySub(identity, sub) {
      if (!canManage(identity) && identity.sub !== sub) throw forbidden();
      const [u] = await listAll(`sub = "${String(sub).replace(/"/g, '')}"`);
      if (!u) return null;
      if (!isStaff(identity) && identity.sub !== sub && attr(u, 'custom:clientName') !== clientOf(identity)) throw forbidden();
      return u;
    },
    async groups(identity, username) {
      if (!canManage(identity)) throw forbidden();
      await checkTarget(identity, username);
      const r = await sdk().send('AdminListGroupsForUserCommand', { Username: username });
      return (r.Groups || []).map((g) => g.GroupName);
    },
    async create(identity, { username, firstName, lastName, email, password, group, clientName, deliveryChecking }) {
      if (!canManage(identity)) throw forbidden();
      if (!username || !email || !password || !group) throw Object.assign(new Error('Identifiant, e-mail, mot de passe et groupe requis'), { status: 400 });
      checkGroup(identity, group);
      const { send } = sdk();
      await send('AdminCreateUserCommand', {
        Username: username,
        TemporaryPassword: password,
        UserAttributes: [
          { Name: 'family_name', Value: lastName || '' },
          { Name: 'given_name', Value: firstName || '' },
          { Name: 'email', Value: email },
          { Name: 'custom:clientName', Value: (isStaff(identity) ? clientName : clientOf(identity)) || '' },
          { Name: 'custom:deliveryChecking', Value: deliveryChecking ? 'true' : 'false' },
        ],
      });
      await send('AdminAddUserToGroupCommand', { Username: username, GroupName: group });
      return { ok: true };
    },
    async update(identity, username, u) {
      if (!canManage(identity)) throw forbidden();
      await checkTarget(identity, username);
      const { send } = sdk();
      await send('AdminUpdateUserAttributesCommand', {
        Username: username,
        UserAttributes: [
          { Name: 'family_name', Value: u.lastName || '' },
          { Name: 'given_name', Value: u.firstName || '' },
          { Name: 'email', Value: u.email },
          { Name: 'custom:clientName', Value: (isStaff(identity) ? u.clientName ?? u.oldClientName : clientOf(identity)) || '' },
          { Name: 'custom:deliveryChecking', Value: u.deliveryChecking ? 'true' : 'false' },
        ],
      });
      if (u.group && u.oldGroup !== u.group) {
        checkGroup(identity, u.group);
        if (u.oldGroup) {
          checkGroup(identity, u.oldGroup);
          await send('AdminRemoveUserFromGroupCommand', { Username: username, GroupName: u.oldGroup });
        }
        await send('AdminAddUserToGroupCommand', { Username: username, GroupName: u.group });
      }
      return { ok: true };
    },
    async remove(identity, username) {
      if (!canManage(identity)) throw forbidden();
      await checkTarget(identity, username);
      await sdk().send('AdminDeleteUserCommand', { Username: username });
      return { ok: true };
    },
  };
}

module.exports = { createCognitoAdmin, CLIENT_ASSIGNABLE_GROUPS };

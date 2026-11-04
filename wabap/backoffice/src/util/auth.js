import { Auth } from "@/util/cognito";

export async function isUserAuthenticated() {
  try {
    await Auth.currentAuthenticatedUser();
    return true;
  } catch (error) {
    return false;
  }
}

export async function isAuthorized() {
  return await isUserInGroup(["admin", "client", "wabap"]);
}

export async function isAdmin() {
  return await isUserInGroup(["admin", "wabap"]);
}

export async function isUserInGroup(requiredGroups) {
  try {
    const user = await Auth.currentAuthenticatedUser();
    const groups =
      user.signInUserSession.accessToken.payload["cognito:groups"] || [];
    return requiredGroups.some((group) => groups.includes(group));
  } catch (error) {
    return false;
  }
}

export async function getUsername() {
  try {
    const user = await Auth.currentAuthenticatedUser();
    return user.username || "NONE";
  } catch (error) {
    return [];
  }
}

export async function getFullName() {
  return (
    (await getAttr("cognito:username")) ?? (await getAttr("cognito:username"))
  );
}

export async function getMail() {
  return await getAttr("email");
}

export async function getClientName() {
  return await getAttr("custom:clientName", null);
}

async function getAttr(key, defaultValue = "??") {
  try {
    const { attributes } = await Auth.currentAuthenticatedUser();
    return attributes[key];
  } catch (error) {
    return defaultValue;
  }
}

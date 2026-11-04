// Gestion des utilisateurs Cognito : désormais faite par le serveur (droits vérifiés côté serveur ;
// un client ne gère que les utilisateurs de son propre compte).
import { rest } from "@/api/client";

export const getUsers = async () => {
  try {
    return await rest("GET", "/admin/users");
  } catch (error) {
    console.error(">>> Error : SERVICE Users", error);
    throw error;
  }
};

export const getUser = async (sub) => {
  try {
    return await rest("GET", `/admin/users/by-sub/${encodeURIComponent(sub)}`);
  } catch (error) {
    console.error(">>> Error : SERVICE User", error);
    throw error;
  }
};

export const getGroupUser = async (userName) => {
  if (userName == undefined) return [];
  try {
    return await rest("GET", `/admin/users/${encodeURIComponent(userName)}/groups`);
  } catch (error) {
    console.error(">>> Error : SERVICE get GROUP", error);
    throw error;
  }
};

export const addUser = async (user) => {
  try {
    await rest("POST", "/admin/users", user);
  } catch (error) {
    console.error(">>> Error : SERVICE Add USER", error);
    throw error;
  }
};

export const updateUser = async (oldUser, newUser) => {
  try {
    await rest("PUT", `/admin/users/${encodeURIComponent(oldUser.username)}`, { oldGroup: oldUser.group, oldClientName: oldUser.clientName, ...newUser });
  } catch (error) {
    console.error(">>> Error : SERVICE Add USER", error);
    throw error;
  }
};

export const deleteUser = async (username) => {
  try {
    await rest("DELETE", `/admin/users/${encodeURIComponent(username)}`);
  } catch (error) {
    console.error(">>> Error : SERVICE DELETE User", error);
    throw error;
  }
};

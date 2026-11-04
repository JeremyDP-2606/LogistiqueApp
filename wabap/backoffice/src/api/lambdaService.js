// Fonctions V1 exécutées par le serveur (anciennes Lambda appelées directement depuis le navigateur).
import { rest } from "@/api/client";

export const updateMissionSubscribersId = async ({ missionId, subscriberIds, oldSubscriberIds }) =>
  rest("PUT", `/missions/${encodeURIComponent(missionId)}/subscribers`, { subscriberIds, oldSubscriberIds });

// Même forme de réponse qu'avant ({ statusCode, body }) pour les écrans existants
export const createTournee = async (missionId) => {
  const tournee = await rest("POST", `/missions/${encodeURIComponent(missionId)}/tournees`, {});
  return { statusCode: 200, body: JSON.stringify(tournee) };
};

export const importCSV = async (json) => rest("POST", "/imports/csv", json);

export const importExcel = async (json) => rest("POST", "/imports/excel", json);

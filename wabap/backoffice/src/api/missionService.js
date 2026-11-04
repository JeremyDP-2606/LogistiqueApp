import { API, graphqlOperation } from "@/api/client";
import {
  createMission,
  deleteMission,
  updateMission,
} from "@/graphql/mutations";
import { listMissions } from "@/graphql/queries";
import { getMission, listMissionsWithSub } from "@/api/queries";

export const missionCreate = async (missionInput) => {
  try {
    console.log("SERVICE creating mission: ", JSON.stringify(missionInput));
    const result = await API.graphql(
      graphqlOperation(createMission, { input: missionInput })
    );
    return result.data.createMission;
  } catch (error) {
    console.error("ERROR SERVICE creating mission: ", error);
    throw error;
  }
};

export const missionUpdate = async (missionInput) => {
  try {
    console.log("SERVICE updating mission: ", JSON.stringify(missionInput));
    const result = await API.graphql(
      graphqlOperation(updateMission, { input: missionInput })
    );
    return result.data.updateMission;
  } catch (error) {
    console.error("ERROR SERVICE updating mission: ", error);
    throw error;
  }
};

export const missionDelete = async (missionId) => {
  try {
    console.log("SERVICE delete mission: [" + missionId + "]");
    const result = await API.graphql(
      graphqlOperation(deleteMission, {
        input: {
          id: missionId,
        },
      })
    );
    return result.data.deleteMission;
  } catch (error) {
    console.error("ERROR SERVICE delete mission: ", error);
    throw error;
  }
};

export const missionGet = async (missionId) => {
  try {
    console.log("SERVICE get mission: [" + missionId + "]");
    const result = await API.graphql(
      graphqlOperation(getMission, { id: missionId })
    );
    return result.data.getMission;
  } catch (error) {
    console.error("ERROR SERVICE get mission: ", error);
    throw error;
  }
};

export const getMissions = async (limit = 100) => {
  try {
    const missionsData = await API.graphql(
      graphqlOperation(listMissionsWithSub, {
        limit: limit,
      })
    );
    return missionsData.data.listMissions.items;
  } catch (error) {
    console.error(">>> Error : SERVICE Missions", error);
    throw error;
  }
};

export const getMissionsByUser = async (userId, limit = 50) => {
  try {
    const missionsData = await API.graphql(
      graphqlOperation(listMissions, {
        filter: {
          livreurID: {
            eq: userId,
          },
        },
        limit: limit,
      })
    );
    return missionsData.data.listMissions.items;
  } catch (error) {
    console.error(">>> Error : SERVICE Missions", error);
    throw error;
  }
};

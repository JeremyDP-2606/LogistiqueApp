import { API, graphqlOperation } from "@/api/client";
import { tourneesByDateWithColis } from "@/api/queries";
import { deleteTournee, updateTournee } from "@/graphql/mutations";
import { getTournee } from "@/graphql/queries";
import { byLivreurOrderDate } from "@/api/queries";

export const getTourneeByMission = async (missionId, nextToken, limit = 30) => {
  try {
    console.log(
      "SERVICE get tournees by mission : " +
        missionId +
        " nextToken : " +
        nextToken
    );
    const result = await API.graphql(
      graphqlOperation(tourneesByDateWithColis, {
        missionTourneeId: missionId,
        limit: limit,
        nextToken: nextToken,
        sortDirection: "DESC",
      })
    );
    return result.data.byMissionOrderDate;
  } catch (error) {
    console.error("ERROR SERVICE get tournee by mission : ", error);
    throw error;
  }
};

export const getLastTourneeByMission = async (missionId) => {
  return (await getTourneeByMission(missionId, null, 1)).items[0] ?? null;
};

export const getTourneeByUser = async (userId, nextToken, limit = 50) => {
  try {
    console.log(
      "SERVICE get tournees by user : " +
        userId +
        " nextToken : " +
        nextToken
    );
    const result = await API.graphql(
      graphqlOperation(byLivreurOrderDate, {
        livreurID: userId,
        limit: limit,
        nextToken: nextToken,
        sortDirection: "DESC",
      })
    );
    return result.data.byLivreurOrderDate;
  } catch (error) {
    console.error("ERROR SERVICE get tournee by user : ", error);
    throw error;
  }
};

export const tourneeGet = async (missionId) => {
  try {
    console.log("SERVICE get tournee : " + missionId);
    const result = await API.graphql(
      graphqlOperation(getTournee, { id: missionId })
    );
    return result.data.getTournee;
  } catch (error) {
    console.error("ERROR SERVICE get tournee : ", error);
    throw error;
  }
};

export const tourneeDelete = async (tourneeId) => {
  try {
    console.log("SERVICE delete tournée: [" + tourneeId + "]");
    const result = await API.graphql(
      graphqlOperation(deleteTournee, {
        input: {
          id: tourneeId,
        },
      })
    );
    return result.data.deleteTournee;
  } catch (error) {
    console.error("ERROR SERVICE delete tournee: ", error);
    throw error;
  }
};


export const tourneeUpdate = async (tourneeInput) => {
  try {
    console.log("SERVICE updating tournee: ", JSON.stringify(tourneeInput));
    const result = await API.graphql(
      graphqlOperation(updateTournee, { input: tourneeInput })
    );
    return result.data.updateTournee;
  } catch (error) {
    console.error("ERROR SERVICE updating tournee: ", error);
    throw error;
  }
};

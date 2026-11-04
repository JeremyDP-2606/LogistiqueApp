import { API, graphqlOperation } from "@/api/client";
import {
  byTourneeOrderPosition,
  bySubscriberOrderDateWithTournee,
} from "@/api/queries";
import { getColis, byColisOrderDate } from "@/graphql/queries";

export const getColisByTournee = async (tourneeId, nextToken, limit = 150) => {
  try {
    console.log(
      "SERVICE get colis by tournee : " +
        tourneeId +
        " nextToken : " +
        nextToken
    );
    const result = await API.graphql(
      graphqlOperation(byTourneeOrderPosition, {
        tourneeColisId: tourneeId,
        limit: limit,
        nextToken: nextToken,
      })
    );
    return result.data.byTourneeOrderPosition;
  } catch (error) {
    console.error("ERROR SERVICE get colis by tournee : ", error);
    throw error;
  }
};
export const getColisBySubscriber = async (
  subscriberId,
  nextToken,
  limit = 50
) => {
  try {
    console.log(
      "SERVICE get colis by subscriber : " +
        subscriberId +
        " nextToken : " +
        nextToken
    );
    const result = await API.graphql(
      graphqlOperation(bySubscriberOrderDateWithTournee, {
        subscriberColisId: subscriberId,
        limit: limit,
        nextToken: nextToken,
        sortDirection: "DESC",
      })
    );
    return result.data.bySubscriberOrderDate;
  } catch (error) {
    console.error("ERROR SERVICE get colis by subscriber : ", error);
    throw error;
  }
};


export const colisGet = async (colisId) => {
  try {
    console.log("SERVICE get colis : " + colisId);
    const resultat = await API.graphql(
      graphqlOperation(getColis, { id: colisId })
    );
    return resultat.data.getColis;
  } catch (error) {
    console.error(">>> Error : SERVICE colis", error);
    throw error;
  }
};


export const getListColisStatus = async (colisId, nextToken, limit = 20) => {
  try {
    console.log("SERVICE get ColisStatus nextToken : colisId=[$colisId] nextToken=[$nextToken]");
    const subscribersData = await API.graphql(
      graphqlOperation(byColisOrderDate, {
        colisLogsId: colisId,
        limit: limit,
        nextToken: nextToken,
        sortDirection: "DESC",
      })
    );
    return subscribersData.data.byColisOrderDate;
  } catch (error) {
    console.error(">>> Error : SERVICE ColisStatus", error);
    throw error;
  }
};
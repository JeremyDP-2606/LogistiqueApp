import { API, graphqlOperation } from "@aws-amplify/api";
import { listSubscribers, getSubscriber } from "@/graphql/queries";
import { subscriberOrderNameWithMission } from "@/api/queries";

export const getSubscribers = async (nextToken, limit = 200) => {
  try {
    console.log("SERVICE get subscribers nextToken : " + nextToken);
    const subscribersData = await API.graphql(
      graphqlOperation(subscriberOrderNameWithMission, {
        type: "subscriber",
        limit: limit,
        nextToken: nextToken,
        sortDirection: "ASC",
        // filter: {
        //   unsubscribed: { eq: false },
        // },
      })
    );
    return subscribersData.data.subscriberOrderName;
  } catch (error) {
    console.error(">>> Error : SERVICE Subscribers", error);
    throw error;
  }
};
export const subscriberGet = async (subscriberId) => {
  try {
    console.log("SERVICE get subscriber : " + subscriberId);
    const resultat = await API.graphql(
      graphqlOperation(getSubscriber, { id: subscriberId })
    );
    return resultat.data.getSubscriber;
  } catch (error) {
    console.error(">>> Error : SERVICE subscriber", error);
    throw error;
  }
};

export const getSubscribersWithoutMission = async (
  missionId = "",
  nextToken,
  limit = 1000
) => {
  try {
    const subscribersData = await API.graphql(
      graphqlOperation(listSubscribers, {
        filter: {
          or: [
            { missionSubscribersId: { eq: null } },
            { missionSubscribersId: { eq: "" } },
            { missionSubscribersId: { attributeExists: false } },
            { missionSubscribersId: { eq: missionId } },
          ],
          unsubscribed: { eq: false },
        },
        limit: limit,
        nextToken: nextToken,
        sortDirection: "DESC",
      })
    );
    return subscribersData.data.listSubscribers;
  } catch (error) {
    console.error(">>> Error : SERVICE Subscribers", error);
    throw error;
  }
};

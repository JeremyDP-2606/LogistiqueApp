/* eslint-disable no-undef */
const AWS = require("aws-sdk");
const docClient = new AWS.DynamoDB.DocumentClient();

const API_WABAP_GRAPHQLAPIIDOUTPUT = process.env.ENV == "prod" ? "nfdn7djf2fcbdjz44rvjidtaf4" : "zjcggzi525bflmgm35w7dji5ui";//TODO : fix

//////////////////
//// TODO : move to TRIGGERMISSION lambda
//////////////////

/**
 * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
 */
exports.handler = async (event) => {
  console.log(`SATART LAMBDA updateMissionSubscribersId : ${JSON.stringify(event)}`);
  const missionId = event.missionId;
  var newSubscriberIds = event.subscriberIds;
  var oldSubscriberIds = event.oldSubscriberIds;
  var allPromises = [];

  if (
    !missionId ||
    !Array.isArray(newSubscriberIds) ||
    newSubscriberIds.length === 0
  ) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: "Invalid input" }),
    };
  }

  // Pour chaque oldSubscriberIds, supprimer l'ID de la mission
  if (Array.isArray(oldSubscriberIds) && oldSubscriberIds.length > 0) {
    const oldSubscriberIdsFilter = oldSubscriberIds.filter(
      (id) => !newSubscriberIds.includes(id)
    );
    const updatePromisesOld = oldSubscriberIdsFilter.map((subscriberId) => {
      const params = {
        TableName: `Subscriber-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
        Key: { id: subscriberId },
        UpdateExpression: "REMOVE missionSubscribersId",
      };
      console.log(`UPDATE : ${JSON.stringify(params)}`);
      return docClient.update(params).promise();
    });
    allPromises = allPromises.concat(updatePromisesOld);
  }

  // Pour chaque subscriberId, mettez à jour l'ID de la mission
  if (Array.isArray(oldSubscriberIds) && oldSubscriberIds.length > 0) {
    newSubscriberIds = newSubscriberIds.filter(
      (id) => !oldSubscriberIds.includes(id)
    );
  }
  const updatePromises = newSubscriberIds.map((subscriberId) => {
    const params = {
      TableName: `Subscriber-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
      Key: { id: subscriberId },
      UpdateExpression: "set missionSubscribersId = :missionId",
      ExpressionAttributeValues: {
        ":missionId": missionId,
      },
    };
    console.log(`UPDATE : ${JSON.stringify(params)}`);
    return docClient.update(params).promise();
  });
  allPromises = allPromises.concat(updatePromises);

  try {
    await Promise.all(allPromises);
    return {
      statusCode: 200,
      body: JSON.stringify({ success: true }),
    };
  } catch (error) {
    console.error("Error updating subscribers:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Failed to update subscribers",
        code: error.code,
      }),
    };
  }
};

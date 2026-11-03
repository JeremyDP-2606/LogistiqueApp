/* eslint-disable no-undef */
/* Amplify Params - DO NOT EDIT
	API_WABAP_GRAPHQLAPIENDPOINTOUTPUT
	API_WABAP_GRAPHQLAPIIDOUTPUT
	ENV
	REGION
Amplify Params - DO NOT EDIT */

const AWS = require("aws-sdk");
const docClient = new AWS.DynamoDB.DocumentClient();

/**
 * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
 */
exports.handler = async (event) => {
  console.log(`EVENT: ${JSON.stringify(event)}`);
  console.log(`ENV: ${process.env.ENV}`);

  await setOwner("Subscriber");
  await setOwner("Mission");
  await setOwner("Inscription");
  await setOwner("Tournee");
  await setOwner("Colis");
  await setOwner("ColisStatus");
  await setOwner("Location");

  return {
    statusCode: 200,
    body: JSON.stringify("ok"),
  };
};

async function setOwner(tableName) {
  console.log(">>>> START TABLE : ", tableName);
  let exclusiveStartKey = null;
  let nb = 0;
  do {
    try {
      const items = await docClient
        .scan({
          TableName: `${tableName}-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
          Limit: 500,
          ExclusiveStartKey: exclusiveStartKey,
          FilterExpression: 'attribute_not_exists(#o)',
          ExpressionAttributeNames: { "#o": "owner" },
        })
        .promise();
        
        console.log(">>>> SCAN : ", items.length);

      exclusiveStartKey = items.LastEvaluatedKey;
      for (const item of items.Items) {
        try {
          await docClient
            .update({
              TableName: `${tableName}-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
              Key: {
                id: item.id,
              },
              UpdateExpression: "SET #o = :o",
              ExpressionAttributeValues: {
                ":o": "France-Antilles",
              },
              ExpressionAttributeNames: { "#o": "owner" },
              ReturnValues: "NONE",
            })
            .promise();
          nb++;
        } catch (error) {
          console.log(`ERROR UPDATE: ${error}`);
        }
      }
    } catch (error) {
      console.log(`ERROR LOOP: ${error}`);
    }
  } while (exclusiveStartKey != undefined);
  console.log("<<<< END TABLE", tableName, " : nb = [", nb, "]");
}

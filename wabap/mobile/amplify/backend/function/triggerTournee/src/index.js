/* eslint-disable no-undef */
const AWS = require("aws-sdk");
const docClient = new AWS.DynamoDB.DocumentClient();

const API_WABAP_GRAPHQLAPIIDOUTPUT = process.env.ENV == "prod" ? "nfdn7djf2fcbdjz44rvjidtaf4" : "zjcggzi525bflmgm35w7dji5ui";//TODO : fix

exports.handler = async (event) => {
  console.log(`START LAMBDA triggerTournee : ${JSON.stringify(event)}`);

  const promises = event.Records.map(async (record) => {
    console.log(record.eventID);
    console.log(record.eventName);

    /////////////////
    // REMOVE
    /////////////////
    if (record.eventName === "REMOVE") {
      const oldTournee = AWS.DynamoDB.Converter.unmarshall(
        record.dynamodb.OldImage
      );

      try {
        // 1. Remove COLIS
        const listColis = await docClient
          .scan({
            TableName: `Colis-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
            FilterExpression: "tourneeColisId = :tourneeId",
            ExpressionAttributeValues: {
              ":tourneeId": oldTournee.id,
            },
          })
          .promise();
        for (const colis of listColis.Items) {
          await docClient
            .delete({
              TableName: `Colis-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
              Key: {
                id: colis.id,
              },
            })
            .promise();

          // 2. Remove ColisStatus
          const listColisStatus = await docClient
            .scan({
              TableName: `ColisStatus-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
              FilterExpression: "colisLogsId = :colisId",
              ExpressionAttributeValues: {
                ":colisId": colis.id,
              },
            })
            .promise();
          for (const colisStatus of listColisStatus.Items) {
            await docClient
              .delete({
                TableName: `ColisStatus-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
                Key: {
                  id: colisStatus.id,
                },
              })
              .promise();
          }
          console.log(
            `REMOVE COLIS_STATUS : nombre=[${listColisStatus.Items.length}]]`
          );
        }
        console.log(`REMOVE COLIS : nombre=[${listColis.Items.length}]]`);
      } catch (error) {
        console.error("ERROR : REMOVE COLIS", error);
      }
    }
  });

  try {
    console.log(`END LOOP`);
    await Promise.all(promises);
    console.log(`END LAMBDA triggerTournee`);
    return {
      statusCode: 200,
      body: JSON.stringify({ success: true }),
    };
  } catch (error) {
    console.error("Error TRIGGER_TOURNEE :", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Failed TRIGGER_TOURNEE",
        code: error.code,
      }),
    };
  }
};

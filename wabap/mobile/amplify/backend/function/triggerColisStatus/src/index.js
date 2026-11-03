/* eslint-disable no-undef */
const AWS = require("aws-sdk");
const docClient = new AWS.DynamoDB.DocumentClient();
const crypto = require("crypto");

const API_WABAP_GRAPHQLAPIIDOUTPUT = process.env.ENV == "prod" ? "nfdn7djf2fcbdjz44rvjidtaf4" : "zjcggzi525bflmgm35w7dji5ui";//TODO : fix

/**
 * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
 */
exports.handler = async (event) => {
  console.log(`START LAMBDA triggerColisStatus : ${JSON.stringify(event)}`);

  const promises = event.Records.map(async (record) => {
    console.log(record.eventID);
    console.log(record.eventName);

    //CREATE
    if (record.eventName === "INSERT") {
      const newColisStatus = AWS.DynamoDB.Converter.unmarshall(
        record.dynamodb.NewImage
      );

      if (
        !("colisLogsId" in newColisStatus) ||
        newColisStatus.colisLogsId === undefined ||
        !("status" in newColisStatus) ||
        newColisStatus.status === undefined
      ) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: "Invalid input" }),
        };
      }

      // 1. Get lastStatus of Colis
      const colisData = await docClient.get({
        TableName: `Colis-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
        Key: {
          id: newColisStatus.colisLogsId,
        }
      }).promise();
      const lastStatusObj = colisData.Item.lastStatus;
      const lastStatus = lastStatusObj ? lastStatusObj.status : null;
      const tourneeId = colisData.Item.tourneeColisId;

      console.log(
        `LAMBDA triggerColisStatus : 1. GET newStatus=[${newColisStatus.status}] - lastStatus=[${lastStatus}] - tourneeId=[${tourneeId}] - colis=[${JSON.stringify(
          colisData
        )}]`
      );

      // Ordering guard: only accept a status that is NEWER than the current
      // lastStatus. Without this, a stale status replayed late (offline queue,
      // network retry, out-of-order stream event) overwrites a fresher one -
      // e.g. a COMPLETED colis reverting to PICKED_UP the next morning.
      const newTime = Date.parse(newColisStatus.createdAt);
      const lastTime =
        lastStatusObj && lastStatusObj.createdAt
          ? Date.parse(lastStatusObj.createdAt)
          : NaN;
      const isNewer = isNaN(lastTime) || (!isNaN(newTime) && newTime > lastTime);

      if (!isNewer) {
        console.log(
          `LAMBDA triggerColisStatus : SKIP stale status newCreatedAt=[${newColisStatus.createdAt}] <= lastCreatedAt=[${lastStatusObj.createdAt}] for colis=[${newColisStatus.colisLogsId}]`
        );
        return;
      }

      // 2. Update Colis lastStatus
      if (newColisStatus.status != "IN_PROGRESS" || (newColisStatus.status == "IN_PROGRESS" && lastStatus != "COMPLETED")) {
        await docClient
        .update({
          TableName: `Colis-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
          Key: {
            id: newColisStatus.colisLogsId,
          },
          UpdateExpression: "set colisLastStatusId = :s, lastStatus = :status",
          ExpressionAttributeValues: {
            ":s": newColisStatus.id,
            ":status": {
              id: newColisStatus.id,
              createdAt: newColisStatus.createdAt,
              status: newColisStatus.status,
              updatedAt: newColisStatus.updatedAt,
            },
          },
        })
        .promise();
      }


      // 3. update colis status just after
      if (
        newColisStatus.status == "COMPLETED" ||
        newColisStatus.status == "ISSUE"
      ) {
        const listColis = await docClient
          .query({
            TableName: `Colis-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
            IndexName: "byTourneeOrderPosition",
            KeyConditionExpression: "tourneeColisId = :t",
            ExpressionAttributeValues: {
              ":t": tourneeId,
            },
            Limit: 300,
            ScanIndexForward: false,
          })
          .promise();
        console.log(
          `LAMBDA triggerColisStatus : 2. GET listColis(${
            listColis?.Items.length ?? 0
          }) of Tournée(${tourneeId})`
        );
        //search first pending colis
        firstPendingColis = null;
        alreadyInprogress = false;
        for (const colis of listColis.Items) {
          if (colis.lastStatus != null) {
            console.log(">>>>> colis [",colis.id,"] : ", colis.lastStatus.status , "(",colis.lastStatus.id,")");

            if (colis.lastStatus.status == "PENDING") {
              firstPendingColis = colis;
            }
            if (colis.lastStatus.status == "IN_PROGRESS") {
              alreadyInprogress = true;
            }
          }
        }


        console.log(
          `LAMBDA triggerColisStatus : 3. PUT ColisStatus IN_PROGRESS(${
            firstPendingColis?.id ?? "null"
          }) of alreadyInprogress=[${alreadyInprogress}]`
        );
        if (firstPendingColis != null && !alreadyInprogress) {
          const idColisStatus = crypto.randomUUID();
          console.log(`PUT STATUS_COLIS to [IN_PROGRESS] : ${idColisStatus}`);
          await docClient
            .put({
              TableName: `ColisStatus-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
              Item: {
                id: idColisStatus,
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString(),
                colisLogsId: firstPendingColis.id,
                status: "IN_PROGRESS",
                owner: newColisStatus.owner
              },
            })
            .promise();
          console.log(`PUT STATUS_COLIS OK`);
        }
      }
    }
  });

  try {
    console.log(`END LOOP`);
    await Promise.all(promises);
    console.log(`END LAMBDA triggerColisStatus`);

    return {
      statusCode: 200,
      body: JSON.stringify({ success: true }),
    };
  } catch (error) {
    console.error("Error triggerColisStatus:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Failed",
        code: error.code,
      }),
    };
  }
};

/* eslint-disable no-undef */
const AWS = require("aws-sdk");
const moment = require("moment-timezone");
const cloudwatchevents = new AWS.CloudWatchEvents();
const lambda = new AWS.Lambda();
const docClient = new AWS.DynamoDB.DocumentClient();

const API_WABAP_GRAPHQLAPIIDOUTPUT =
  process.env.ENV == "prod"
    ? "nfdn7djf2fcbdjz44rvjidtaf4"
    : "zjcggzi525bflmgm35w7dji5ui"; //TODO : fix

exports.handler = async (event) => {
  console.log(`START LAMBDA triggerMission : ${JSON.stringify(event)}`);

  const promises = event.Records.map(async (record) => {
    console.log(record.eventID);
    console.log(record.eventName);

    /////////////////
    // CREATE/UPDATE
    /////////////////
    if (record.eventName === "INSERT" || record.eventName === "MODIFY") {
      const newMission = AWS.DynamoDB.Converter.unmarshall(
        record.dynamodb.NewImage
      );

      if (
        !("livreurID" in newMission) ||
        newMission.livreurID === undefined ||
        !("id" in newMission) ||
        newMission.id === undefined
      ) {
        return {
          statusCode: 400,
          body: JSON.stringify({ error: "Invalid input" }),
        };
      }

      if (
        !("startTime" in newMission) ||
        newMission.startTime === undefined ||
        !("daysOfWeek" in newMission) ||
        newMission.daysOfWeek === undefined ||
        !("startTimeZone" in newMission) ||
        newMission.startTimeZone === undefined
      ) {
        if (record.eventName === "MODIFY") {
          console.log(`REMOVE REPEAT : missionId=[${newMission.id}]`);
          await removeRepeat(newMission.id);
        }
        return {
          statusCode: 200,
          body: JSON.stringify({ error: "No repeat" }),
        };
      }

      // 1. Create EVENT
      const ruleName = `Mission_${newMission.id}`;
      const cronExpression = generateCronExpression(
        newMission.startTime,
        newMission.daysOfWeek,
        newMission.startTimeZone,
        !!newMission.generateDayBefore
      );
      await cloudwatchevents
        .putRule({
          Name: ruleName,
          ScheduleExpression: cronExpression,
          State: "ENABLED",
        })
        .promise();
      console.log(
        `PUT RULES : name=[${ruleName}] - cronExpression=[${cronExpression}]`
      );

      // 2. Create TARGET
      const targerId = `Mission_target_${newMission.id}`;
      const lambdaArn = `arn:aws:lambda:us-east-1:673747581604:function:createTournee-${process.env.ENV}`;
      const input = JSON.stringify({
        missionId: newMission.id,
        createForTomorrow: !!newMission.generateDayBefore,
      });
      await cloudwatchevents
        .putTargets({
          Rule: ruleName,
          Targets: [
            {
              Id: targerId,
              Arn: lambdaArn,
              Input: input,
            },
          ],
        })
        .promise();
      console.log(
        `PUT TARGET : targerId=[${targerId}] - lambdaArn=[${lambdaArn}] - input=[${input}]`
      );

      // 3. Add permission
      try {
        const statementId = `StatementId_${newMission.id}`;
        const lambdaName = `createTournee-${process.env.ENV}`;
        const ruleArn = `arn:aws:events:us-east-1:673747581604:rule/${ruleName}`;
        await lambda
          .addPermission({
            Action: "lambda:InvokeFunction",
            FunctionName: lambdaName,
            Principal: "events.amazonaws.com",
            SourceArn: ruleArn,
            StatementId: statementId,
          })
          .promise();
        console.log(
          `PUT PERMISSION : statementId=[${statementId}] - ruleArn=[${ruleArn}] - Action=[InvokeFunction]`
        );
      } catch (error) {
        console.error("ERROR : PUT PERMISSION", error);
      }

      ///////////
      // DELETTE
      ///////////
    } else if (record.eventName === "REMOVE") {
      const oldMission = AWS.DynamoDB.Converter.unmarshall(
        record.dynamodb.OldImage
      );

      // 1. 2. 3. Remove REPEAT
      removeRepeat(oldMission.id);

      // 4. Remove SUBSCRIBERS
      try {
        const subscribers = await docClient
          .scan({
            TableName: `Subscriber-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
            FilterExpression: "missionSubscribersId = :missionId",
            ExpressionAttributeValues: {
              ":missionId": oldMission.id,
            },
          })
          .promise();
        for (const subscriber of subscribers.Items) {
          try {
            await docClient
              .update({
                TableName: `Subscriber-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
                Key: {
                  id: subscriber.id,
                },
                UpdateExpression: "REMOVE missionSubscribersId",
              })
              .promise();
          } catch (error) {
            console.error("ERROR : REMOVE SUBSCRIBER", error);
          }
        }
        console.log(
          `REMOVE SUBSCRIBER : nombre=[${subscribers.Items.length}]]`
        );
      } catch (error) {
        console.error("ERROR : REMOVE SUBSCRIBER", error);
      }

      // 5. Remove INSCRIPTIONS
      try {
        const inscriptions = await docClient
          .scan({
            TableName: `Inscription-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
            FilterExpression: "missionInscriptionsId = :missionId",
            ExpressionAttributeValues: {
              ":missionId": oldMission.id,
            },
          })
          .promise();
        for (const inscription of inscriptions.Items) {
          await docClient
            .delete({
              TableName: `Inscription-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
              Key: {
                id: inscription.id,
              },
            })
            .promise();
        }
        console.log(
          `REMOVE INSCRIPTION : nombre=[${inscriptions.Items.length}]]`
        );
      } catch (error) {
        console.error("ERROR : REMOVE INSCRIPTION", error);
      }

      // 6. Remove TOURNEES
      try {
        const tournees = await docClient
          .scan({
            TableName: `Tournee-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
            FilterExpression: "missionTourneeId = :missionId",
            ExpressionAttributeValues: {
              ":missionId": oldMission.id,
            },
          })
          .promise();
        for (const tournee of tournees.Items) {
          await docClient
            .delete({
              TableName: `Tournee-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
              Key: {
                id: tournee.id,
              },
            })
            .promise();
        }
        console.log(`REMOVE TOURNEE : nombre=[${tournees.Items.length}]]`);
      } catch (error) {
        console.error("ERROR : REMOVE TOURNEE", error);
      }
    }
  });

  try {
    console.log(`END LOOP`);

    await Promise.all(promises);

    console.log(`END LAMBDA triggerMission`);

    return {
      statusCode: 200,
      body: JSON.stringify({ success: true }),
    };
  } catch (error) {
    console.error("Error create CRON:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Failed to create CRON",
        code: error.code,
      }),
    };
  }
};

function generateCronExpression(
  startTime,
  daysOfWeek,
  startTimeZone,
  generateDayBefore
) {
  const hour = Math.trunc(startTime);
  const minutes = Math.round((startTime - Math.trunc(startTime)) * 60);

  console.log(
    `DEBUG generateCronExpression : ${hour}h${minutes} 2023-09-05 - ${daysOfWeek} - ${startTimeZone}`
  );

  const utcDate = moment
    .tz(
      "2023-09-05 " +
        (hour < 10 ? "0" + hour : hour) +
        ":" +
        (minutes < 10 ? "0" + minutes : minutes),
      startTimeZone
    )
    .utc();

  console.log("DEBUG generateCronExpression : utcDate=[" + utcDate + "]");

  const utcHour = utcDate.hour();
  const utcMinutes = utcDate.minutes();
  const utcDay = utcDate.date();
  if (utcDay == 6) {
    // +1 compared to 2023-09-05
    const lastElement = daysOfWeek.pop();
    daysOfWeek.unshift(lastElement);
  } else if (utcDay == 4) {
    // -1 compared to 2023-09-05
    const firstElement = daysOfWeek.shift();
    daysOfWeek.push(firstElement);
  }

  if (generateDayBefore) {
    const firstElement = daysOfWeek.shift();
    daysOfWeek.push(firstElement);
  }

  const days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
  const selectedDays = daysOfWeek
    .map((isSelected, index) => (isSelected ? days[index] : null))
    .filter((day) => day);

  const cron = `cron(${utcMinutes} ${utcHour} ? * ${selectedDays.join(",")} *)`;
  console.log(
    `DEBUG generateCronExpression : ${utcHour}h${utcMinutes} ${utcDay} - ${daysOfWeek} - ${cron}`
  );

  return cron;
}

async function removeRepeat(missionId) {
  // 1. Remove PERMISSION
  try {
    const statementId = `StatementId_${missionId}`;
    const lambdaName = `createTournee-${process.env.ENV}`;
    await lambda
      .removePermission({
        StatementId: statementId,
        FunctionName: lambdaName,
      })
      .promise();
    console.log(`REMOVE PERMISSION : statementId=[${statementId}]`);
  } catch (error) {
    console.error("ERROR : REMOVE PERMISSION", error);
  }

  // 2. Remove TARGETS
  try {
    const ruleName = `Mission_${missionId}`;
    const targets = await cloudwatchevents
      .listTargetsByRule({ Rule: ruleName })
      .promise();
    if (targets.Targets && targets.Targets.length > 0) {
      const ids = targets.Targets.map((t) => t.Id);
      await cloudwatchevents
        .removeTargets({
          Rule: ruleName,
          Ids: ids,
        })
        .promise();
      console.log(`REMOVE TARGET : name=[${ruleName}] - ids=[${ids}]`);
    }
  } catch (error) {
    console.error("ERROR : REMOVE TARGET", error);
  }

  // 3. Remove RULE
  try {
    const ruleName = `Mission_${missionId}`;
    await cloudwatchevents
      .deleteRule({
        Name: ruleName,
      })
      .promise();
    console.log(`REMOVE RULE : name=[${ruleName}]]`);
  } catch (error) {
    console.error("ERROR : REMOVE RULE", error);
  }
}

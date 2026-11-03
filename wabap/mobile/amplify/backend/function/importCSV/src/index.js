/* eslint-disable no-undef */
/* Amplify Params - DO NOT EDIT
	API_WABAP_GRAPHQLAPIENDPOINTOUTPUT
	API_WABAP_GRAPHQLAPIIDOUTPUT
	ENV
	REGION
Amplify Params - DO NOT EDIT */

const AWS = require("aws-sdk");
const { getSecret } = require("./secrets");
const docClient = new AWS.DynamoDB.DocumentClient();
let Client = require("ssh2-sftp-client");
const fs = require("fs");
const csv = require("csv-parser");
const crypto = require("crypto");
const moment = require("moment");
const axios = require("axios");

/**
 * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
 */
exports.handler = async (event) => {
  console.log(`LAMBDA IMPORT CSV START: ${JSON.stringify(event)}`);
  startReport();

  if (event.clientName == undefined) throw new Error("clientName is required");

  // READ CSV FILE
  let csvSubs = await getCSVFile(event);
  if (csvSubs != null) {
    //Get all missions
    const missions = await getMissions(event.clientName);

    console.log(
      ">>>>> READ DB nb missions = [",
      safeLength(missions),
      "] - missions=[",
      missions,
      "]"
    );

    // browse all DB subscribers
    let exclusiveStartKey = null;
    do {
      const dbSubs = await docClient
        .scan({
          TableName: `Subscriber-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
          Limit: 100,
          ExclusiveStartKey: exclusiveStartKey,
          FilterExpression: "#o = :o",
          ExpressionAttributeValues: {
            ":o": event.clientName,
          },
          ExpressionAttributeNames: { "#o": "owner" },
        })
        .promise();

      console.log(
        ">>>>> READ DB nb dbSub = [",
        safeLength(dbSubs.Items),
        "] - LastEvaluatedKey=[",
        dbSubs.LastEvaluatedKey,
        "]"
      );

      exclusiveStartKey = dbSubs.LastEvaluatedKey;
      for (const dbSub of dbSubs.Items) {
        let indexCsvSub = csvSubs.findIndex((s) => {
          return s.NOABO !== undefined && s.NOABO === dbSub.numabo;
        });
        let csvSub =
          indexCsvSub !== -1 ? csvSubs.splice(indexCsvSub, 1)[0] : null;

        // UPDATE SUBSCRIBER
        if (csvSub !== null) {
          let updatedSub = await getUpdatedSub(csvSub, dbSub, missions);
          reportUpdate(updatedSub);
          await updateSub(updatedSub);
        } else {
          if (
            dbSub.unsubscribed == false ||
            dbSub.missionSubscribersId != undefined
          ) {
            let updatedSub = getUnsubscribedSub(dbSub);
            reportDelete(updatedSub);
            await updateSub(updatedSub);
          }
        }
      }
    } while (exclusiveStartKey !== undefined);

    // CREATE SUBSCRIBER
    for (const sub of csvSubs) {
      let newSub = await getNewSub(sub, missions, event.clientName);
      if (newSub == null) {
        console.log(">>>>> CREATE sub = newSub=[NULL] NEXT");
        continue;
      }
      if (newSub.secteur != undefined) {// a fixers
        reportCreate(newSub);
        await createSub(newSub);
      }
    }
  } else {
    report("ERROR : CSV file not found or incorrect");
    console.log(">>>>> ERROR READ CSV FILE : CSV file not found or incorrect");
  }

  console.log(">>>>> SEND REPORT EMAIL");
  await sendReport();

  console.log(">>>>> END OK !");
  return {
    statusCode: 200,
    body: JSON.stringify("import CSV finish without error"),
  };
};

/**
 * GETTER CSV
 */
async function getCSVFile(event) {
  if (!event.data && !event.ftp) {
    console.error("No date and no ftp info !");
    return null;
  }
  const tmpFilePath = "/tmp/subscribers.csv";

  try {
    if (event.data) {
      report(`IMPORT CSV FROM DATA size=${event.data?.length ?? -1}`);

      // Write data in tmp file
      await new Promise((resolve, reject) => {
        const dst = fs.createWriteStream(tmpFilePath);
        dst.write(event.data, (err) => {
          if (err) {
            reject(new Error("Error during write data in tmp file : " + err.message));
          } else {
            dst.end(resolve);
          }
        });
      });
    } else {
      const filename = getFileNameCSV(event.ftp.filename);
      report("IMPORT CSV FROM FTP : " + filename);

      await retry(
        async () => {
          const ftp = new Client();

          ftp.on("error", (err) => console.error("SFTP ERROR:", err.message));
          ftp.on("close", () => console.log("SFTP CONNECTION CLOSED"));

          await ftp.connect({
            host: event.ftp.host,
            port: event.ftp.port,
            username: event.ftp.username,
            password: event.ftp.password,
            debug: (msg) => {
              if (msg.startsWith("CLIENT[sftp]")) {
                console.log(`SFTP DEBUG: ${msg}`);
              }
            },
          });
          try {
            await ftp.get(filename, tmpFilePath);
            console.log(`>>>>> Download FTP file END (${filename})`);
          } finally {
            ftp.end();
          }
        }, 3, 30
      );
    }

    // Lecture et parsing du fichier CSV
    const csvSubs = await new Promise((resolve, reject) => {
      const results = [];
      fs.createReadStream(tmpFilePath)
        .pipe(csv({ separator: "|" }))
        .on("data", (data) => results.push(data))
        .on("end", () => resolve(results))
        .on("error", (err) =>
          reject(
            new Error(
              "Error during reading/parsing CSV file : " + err.message
            )
          )
        );
    });

    report("CSV FILE LINE : " + safeLength(csvSubs));

    // Validation CSV file
    if (
      !csvSubs ||
      csvSubs.length === 0 ||
      ![
        "NOABO",
        "VOL1",
        "VOL2",
        "VOL3",
        "VOL4",
        "VOL5",
        "VOL6",
        "NOM_ABO",
        "GPS",
      ].every((field) => Object.prototype.hasOwnProperty.call(csvSubs[0], field))
    ) {
      console.error(
        ">>>>> ERROR: CSV NOT VALIDE csvSubs[0]=",
        csvSubs.length === 0 ? "LENGTH=0" : JSON.stringify(csvSubs[0])
      );
      report("ERROR CSV : NOT CORRECT");
      return null;
    }

    return csvSubs;
  } catch (err) {
    report("ERROR getCSVFile() : " + err.message);
    return null;
  }
}

async function retry(action, maxAttempts, delay) {
  let attempt = 0;
  while (attempt < maxAttempts) {
    try {
      return await action();
    } catch (err) {
      attempt++;
      if (err.message.includes("No such file")) {//Skip retry, connection OK but no file
        throw err;
      }
      if (attempt >= maxAttempts) {
        console.error(`All ${maxAttempts} attempts failed.`);
        sendErrorFTP();
        throw err;
      }
      console.warn(
        `Attempt ${attempt} failed. Retrying in ${delay} seconds... (${err.message})`
      );
      await new Promise((resolve) => setTimeout(resolve, delay*1000));
    }
  }
}

/**
 * GETTER MISSIONS
 */
async function getMissions(clientName) {
  let rep = await docClient
    .scan({
      TableName: `Mission-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
      Limit: 100,
      FilterExpression: "#o = :owner",
      ProjectionExpression: "id, #n",
      ExpressionAttributeNames: { "#n": "name", "#o": "owner" },
      ExpressionAttributeValues: {
        ":owner": clientName,
      },
    })
    .promise();
  let missions = rep.Items ?? [];
  let mapMissions = {};
  missions.forEach((m) => {
    mapMissions[cleanSecteurName(m.name)] = m.id;
  });
  return mapMissions;
}

/**
 * GETTER CSV
 */
function getCsvName(s) {
  if (has(s, "NOM_ABO")) return s["NOM_ABO"];
  let name = has(s, "VOL1") ? s["VOL1"] : null;
  if (name === null) name = has(s, "VOL2") ? s["VOL2"] : null;
  return name;
}
function getCsvAdresse(s) {
  let address = has(s, "VOL3") ? s["VOL3"] : "";
  address = address + (has(s, "VOL4") ? " " + s["VOL4"] : "");
  address = address + (has(s, "VOL5") ? " " + s["VOL5"] : "");
  address = address + (has(s, "VOL6") ? " " + s["VOL6"] : "");
  address = address.trim();
  return address !== "" ? address : null;
}
function getCsvPhone1(s) {
  let phone1 = has(s, "TEL_FIXE") ? s["TEL_FIXE"] : null;
  if (phone1 === null) phone1 = has(s, "TEL_POR") ? s["TEL_POR"] : null;
  return phone1;
}
function getCsvPhone2(s) {
  return has(s, "TEL_FIXE") && has(s, "TEL_POR") ? s["TEL_POR"] : null;
}
function getCsv(s, key) {
  return has(s, key) ? s[key] : null;
}

/**
 * GET REQ
 */
async function getNewSub(csvSub, missions, clientName) {
  let numabo = getCsv(csvSub, "NOABO");
  let name = getCsvName(csvSub);
  if (numabo === null || name === null) {
    console.log(
      ">>>>> ERROR SUB CSV INCORRECT numabo=[",
      numabo,
      "] - name=[",
      name,
      "] - sub =",
      csvSub
    );
    return null;
  }
  let newSub = {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    nb: 1,
    type: "subscriber",
    __typename: "Subscriber",
    name: name,
    numabo: numabo,
    unsubscribed: false,
    owner: clientName,
  };
  let address = getCsvAdresse(csvSub);
  if (address !== null) newSub["address"] = address;
  let phone1 = getCsvPhone1(csvSub);
  if (phone1 !== null) newSub["phone1"] = phone1;
  let phone2 = getCsvPhone2(csvSub);
  if (phone2 !== null) newSub["phone2"] = phone2;
  let secteur = getCsv(csvSub, "SECTEUR");
  if (secteur !== null) {
    newSub["secteur"] = secteur;
    let idMission = missions[cleanSecteurName(secteur)];
    if (idMission !== undefined) {
      newSub["missionSubscribersId"] = idMission;
    }
  }
  let instructions = getCsv(csvSub, "CONSIGNE_LIV");
  if (instructions !== null) newSub["instructions"] = instructions;
  let nb = getCsv(csvSub, "QTE");
  if (nb !== null) newSub["nb"] = nb;
  let gps = getCsv(csvSub, "GPS");
  if (gps !== null) {
    let gpsSplit = gps.split(",");
    if (gpsSplit.length == 2) {
      newSub["latitude"] = cleanCoordinate(gpsSplit[0]);
      newSub["longitude"] = cleanCoordinate(gpsSplit[1]);
    }
  } else {
    gps = await getGeocoding(address);
    if (gps != undefined) {
      newSub["latitude"] = gps["lat"];
      newSub["longitude"] = gps["lng"];
    }
  }
  return newSub;
}
async function getUpdatedSub(csvSub, dbSub, missions) {
  let updateSub = {};
  let name = getCsvName(csvSub);
  if (name != dbSub.name) updateSub["name"] = name;
  let address = getCsvAdresse(csvSub);
  if (address != dbSub.address) {
    updateSub["address"] = address;
    let gpsCSV = getCsv(csvSub, "GPS");
    if (gpsCSV == undefined) {
      let geocoding = await getGeocoding(address);
      if (geocoding != undefined) {
        updateSub["latitude"] = geocoding["lat"];
        updateSub["longitude"] = geocoding["lng"];
      }
    }
  }
  let phone1 = getCsvPhone1(csvSub);
  if (phone1 != dbSub.phone1) updateSub["phone1"] = phone1;
  let phone2 = getCsvPhone2(csvSub);
  if (phone2 != dbSub.phone2) updateSub["phone2"] = phone2;
  let secteur = getCsv(csvSub, "SECTEUR");
  if (secteur != dbSub.secteur) {
    updateSub["secteur"] = secteur;
  }
  if (
    dbSub.missionSubscribersId == undefined ||
    (dbSub.missionSubscribersId == missions[cleanSecteurName(dbSub.secteur)] &&
      updateSub["secteur"] != undefined)
  ) {
    //si aucune mission OU si il est dans la mission de son secteur et que son secteur est màj
    let idMission = missions[cleanSecteurName(secteur)];
    if (idMission !== undefined) {
      updateSub["missionSubscribersId"] = idMission;
    }
  }
  let instructions = getCsv(csvSub, "CONSIGNE_LIV");
  if (instructions != dbSub.instructions) {
    updateSub["instructions"] = instructions;
  }
  let nb = getCsv(csvSub, "QTE");
  if (nb != dbSub.nb) updateSub["nb"] = nb;
  let gps = getCsv(csvSub, "GPS");
  if (gps) {
    let gpsSplit = gps.split(",");
    if (gpsSplit.length == 2) {
      let latitude = cleanCoordinate(gpsSplit[0]);
      let longitude = cleanCoordinate(gpsSplit[1]);
      if (latitude !== dbSub.latitude) updateSub["latitude"] = latitude;
      if (longitude !== dbSub.longitude) updateSub["longitude"] = longitude;
    }
  }
  if (dbSub.unsubscribed == true) updateSub["unsubscribed"] = false;
  if (Object.keys(updateSub).length === 0) return null;
  updateSub["id"] = dbSub.id;
  updateSub["updatedAt"] = new Date().toISOString();
  return updateSub;
}

function getUnsubscribedSub(dbSub) {
  let sub = {
    id: dbSub.id,
    unsubscribed: true,
    missionSubscribersId: null,
  };
  return sub;
}

/**
 * REQ SUBSCRIBER
 */
async function createSub(sub) {
  console.log(">>>>> CREATE NEW SUBSCRIBER : newSub=[", sub, "]");
  if (sub !== null) {
    await docClient
      .put({
        TableName: `Subscriber-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
        Item: sub,
      })
      .promise();
  }
}

async function updateSub(sub) {
  let expressionAttributeValues = {};
  let expressionAttributeNames = {};
  let updateExpression = {
    SET: [],
    REMOVE: [],
  };
  if (sub) {
    Object.keys(sub).forEach((key) => {
      if (key !== "id") {
        const attributeValueKey = `:${key}`;
        const attributeNameKey = `#${key}`;
        expressionAttributeNames[attributeNameKey] = key;
        if (sub[key] !== null) {
          updateExpression.SET.push(
            `${attributeNameKey} = ${attributeValueKey}`
          );
          expressionAttributeValues[attributeValueKey] = sub[key];
        } else {
          updateExpression.REMOVE.push(attributeNameKey);
        }
      }
    });
  }

  let updateExpressionStr = "";
  if (updateExpression.SET.length) {
    updateExpressionStr += "SET " + updateExpression.SET.join(", ");
  }
  if (updateExpression.REMOVE.length) {
    if (updateExpressionStr.length) updateExpressionStr += " ";
    updateExpressionStr += "REMOVE " + updateExpression.REMOVE.join(", ");
  }

  if (updateExpressionStr.length) {
    let options = {
      TableName: `Subscriber-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
      Key: {
        id: sub.id,
      },
      ExpressionAttributeNames: expressionAttributeNames,
      UpdateExpression: updateExpressionStr,
      ReturnValues: "NONE",
    };
    if (Object.keys(expressionAttributeValues).length > 0) {
      options["ExpressionAttributeValues"] = expressionAttributeValues;
    }
    console.log(">>>>> UPDATE SUBSCRIBER : options=[", options, "]");
    await docClient.update(options).promise();
  }
}

/**
 * UTILS
 */
function cleanCoordinate(str) {
  return str?.replace(/[^-.0-9]/g, "");
}
function cleanSecteurName(str) {
  return str?.toLowerCase().replace(/\./g, "") ?? "";
}
function getFileNameCSV(template) {
  return moment().format(template);
}
function safeLength(obj) {
  if (Array.isArray(obj)) return obj.length;
  if (typeof obj === "object") return Object.keys(obj).length;
  return -1;
}
function has(obj, key) {
  if (Array.isArray(key)) {
    return key.every((k) => has(obj, k));
  } else if (obj !== null && typeof obj === "object") {
    return (
      key in obj &&
      obj[key] !== null &&
      obj[key] !== undefined &&
      obj[key] !== ""
    );
  } else {
    return false;
  }
}

async function getGeocoding(address) {
  if (address == undefined) return null;
  const endpoint = `https://maps.googleapis.com/maps/api/geocode/json?address=${address}&key=${await getSecret("GOOGLE_MAPS_API_KEY")}`;
  try {
    console.log(`GET GOOGLE API GEOCODING : ${endpoint.replace(/key=[^&]+/, "key=***")}`);
    const rep =  await axios.get(endpoint);
    console.log("REP GOOGLE API GEOCODING :", rep.data);
    if (rep.data["status"] == "OK") {
      return rep.data["results"][0]["geometry"]["location"];
    } else {
      return null;
    }
  } catch (error) {
    console.error("ERROR GOOGLE API GEOCODING :", error);
    throw error;
  }
}

/**
 * REPORT
 */

const SES = new AWS.SES({ region: process.env.REGION });

let REPORT = "";
let NB_UPDATE = 0;
let NB_DELETE = 0;
let NB_CREATE = 0;
const TO_EMAIL = ["wabapsas@gmail.com", "julien@wabap.fr", "lainy@wabap.fr"];
const TO_EMAIL_DEV = ["wabapsas@gmail.com"];
const TO_ERROR_EMAIL = ["wabapsas@gmail.com", "julien@wabap.fr", "lainy@wabap.fr", "nicolas.doiteau@gmail.com"];
const TO_ERROR_EMAIL_DEV = ["nicolas.doiteau@gmail.com"];

function startReport() {
  REPORT = "";
  NB_UPDATE = 0;
  NB_DELETE = 0;
  NB_CREATE = 0;
  report("IMPORT CSV START : " + new Date().toISOString());
}

function report(msg) {
  REPORT += msg + "\n";
  console.log(">>> REPORT : " + msg);
}

function reportUpdate(sub) {
  if (sub !== null) {
    NB_UPDATE++;
    report(" >> UPDATE SUBSCRIBER : " + JSON.stringify(sub));
  }
}

function reportCreate(sub) {
  if (sub !== null) {
    NB_CREATE++;
    report(" >> CREATE SUBSCRIBER : " + JSON.stringify(sub));
  }
}

function reportDelete(sub) {
  if (sub !== null) {
    NB_DELETE++;
    report(" >> DELETE SUBSCRIBER : " + JSON.stringify(sub));
  }
}

function getReport() {
  return REPORT;
}

async function sendErrorFTP() {
  const to = process.env.ENV == "prod" ? TO_ERROR_EMAIL : TO_ERROR_EMAIL_DEV;
  var params = {
    Destination: {
      ToAddresses: to,
    },
    Message: {
      Body: {
        Text: {
          Data: "ERREUR lors de l'importation du CSV. Impossible de se connecter au serveurt FTP aprés 3 tentatives.",
        },
      },

      Subject: { Data: "[WABAP] !! ERREUR !! import CSV" },
    },
    Source: "rapport@wabap.fr",
  };

  try {
    await SES.sendEmail(params).promise();
    console.log(">>>> SEND EMAIL ERROR TO [", to, "] : OK");
  } catch (error) {
    console.log(
      ">>>> ERROR SEND EMAIL ERROR TO [",
      to,
      "] : ERREUR=[",
      error,
      "] : ",
      error.stack
    );
  }
}


async function sendReport() {
  report(" ---------------------------- ");
  report(" --- NB UPDATE : " + NB_UPDATE);
  report(" --- NB DELETE : " + NB_DELETE);
  report(" --- NB CREATE : " + NB_CREATE);
  report("IMPORT CSV END : " + new Date().toISOString());

  const to = process.env.ENV == "prod" ? TO_EMAIL : TO_EMAIL_DEV;
  var params = {
    Destination: {
      ToAddresses: to,
    },
    Message: {
      Body: {
        Text: { Data: getReport() },
      },

      Subject: { Data: "RAPPORT import CSV : " + new Date().toISOString() },
    },
    Source: "rapport@wabap.fr",
  };

  try {
    await SES.sendEmail(params).promise();
    console.log(">>>> SEND EMAIL TO [", to, "] : OK");
  } catch (error) {
    console.log(
      ">>>> ERROR SEND EMAIL TO [",
      to,
      "] : ERREUR=[",
      error,
      "] : ",
      error.stack
    );
  }
}

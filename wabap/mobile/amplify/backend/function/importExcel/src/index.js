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
const fs = require("fs");
const XLSX = require("xlsx");
const crypto = require("crypto");
const axios = require("axios");

// Clé API Google Maps 


async function importExcel(filePath) {
  try {
    // Lire le fichier Excel
    const workbook = XLSX.readFile(filePath);
    const sheetName = workbook.SheetNames[0]; // Prend la première feuille du fichier
    const worksheet = workbook.Sheets[sheetName];

    // Convertir la feuille en tableau d'objets JSON
    const data = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

    // Transformer les données en tableau d'objets (en supposant que la première ligne contient les en-têtes)
    const headers = data[0]; // La première ligne contient les en-têtes
    const rows = data.slice(1); // Les lignes suivantes contiennent les données

    const result = rows.map((row) => {
      const obj = {};
      headers.forEach((header, index) => {
        obj[header] = row[index]; // Associe chaque en-tête à sa valeur dans la ligne
      });
      return obj;
    });

    return result;
  } catch (error) {
    console.error("Erreur lors de la lecture du fichier Excel :", error);
    throw error;
  }
}

/**
 * Effectue le géocoding d'une adresse en utilisant l'API Google Maps.
 * @param {string} address - Adresse à géocoder.
 * @returns {Object} - Coordonnées GPS { lat, lng }.
 */
async function getGeocoding(address) {
  if (!address) return null;

  const endpoint = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${await getSecret("GOOGLE_MAPS_API_KEY")}`;

  try {
    console.log(`GET GOOGLE API GEOCODING : ${endpoint.replace(/key=[^&]+/, "key=***")}`);
    const response = await axios.get(endpoint);
    console.log("REP GOOGLE API GEOCODING :", response.data);

    if (response.data.status === "OK") {
      return response.data.results[0].geometry.location; // Retourne { lat, lng }
    } else {
      console.error("Erreur de géocoding :", response.data.status);
      return null;
    }
  } catch (error) {
    console.error("ERREUR GOOGLE API GEOCODING :", error);
    throw error;
  }
}

/**
 * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
 */
exports.handler = async (event) => {
  console.log(`LAMBDA IMPORT EXCEL START: ${JSON.stringify(event)}`);
  startReport();

  if (event.clientName == undefined) throw new Error("clientName is required");

  // Chemin du fichier temporaire
  const tmpFilePath = "/tmp/subscribers.xlsx";

  try {
    // Écrire les données dans un fichier temporaire
    if (event.data) {
      await fs.promises.writeFile(tmpFilePath, event.data, "base64");
    } else if (event.ftp) {
      // Télécharger le fichier depuis FTP (implémentez cette partie si nécessaire)
      throw new Error("FTP non implémenté dans cet exemple");
    } else {
      throw new Error("Aucune donnée ou information FTP fournie");
    }

    // Lire le fichier Excel
    const excelData = await importExcel(tmpFilePath);
    console.log("Données Excel lues :", excelData);

    // Récupérer toutes les missions
    const missions = await getMissions(event.clientName);

    // Parcourir tous les abonnés existants dans la base de données
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
        // Trouver l'abonné correspondant dans le fichier Excel
        const excelSub = excelData.find((s) => "FDJ"+s["N° PDV"] === dbSub.numabo);

        // Mettre à jour l'abonné existant
        if (excelSub) {
          const updatedSub = await getUpdatedSub(excelSub, dbSub, missions);
          if (updatedSub) {
            reportUpdate(updatedSub);
            await updateSub(updatedSub);
          }
        } else {
          // Désinscrire l'abonné s'il n'est plus dans le fichier Excel
          if (!dbSub.unsubscribed || dbSub.missionSubscribersId) {
            const unsubscribedSub = getUnsubscribedSub(dbSub);
            reportDelete(unsubscribedSub);
            await updateSub(unsubscribedSub);
          }
        }
      }
    } while (exclusiveStartKey);

    // Créer de nouveaux abonnés pour les entrées du fichier Excel non trouvées dans la base de données
    for (const excelSub of excelData) {
      const dbSub = await getSubscriberByNumabo("FDJ"+excelSub["N° PDV"]);
      if (!dbSub) {
        const newSub = await getNewSub(excelSub, missions, event.clientName);
        if (newSub) {
          reportCreate(newSub);
          await createSub(newSub);
        }
      }
    }

    console.log(">>>>> SEND REPORT EMAIL");
    await sendReport();

    return {
      statusCode: 200,
      body: JSON.stringify("Import Excel terminé avec succès"),
    };
  } catch (error) {
    console.error("Erreur lors de l'import Excel :", error);
    report("ERROR: " + error.message);
    await sendReport();
    return {
      statusCode: 500,
      body: JSON.stringify("Erreur lors de l'import Excel"),
    };
  }
};

// Fonctions utilitaires (report, sendReport, etc.)
let REPORT = "";
let NB_UPDATE = 0;
let NB_DELETE = 0;
let NB_CREATE = 0;

function startReport() {
  REPORT = "";
  NB_UPDATE = 0;
  NB_DELETE = 0;
  NB_CREATE = 0;
  report("IMPORT EXCEL START : " + new Date().toISOString());
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

async function sendReport() {
  report(" ---------------------------- ");
  report(" --- NB UPDATE : " + NB_UPDATE);
  report(" --- NB DELETE : " + NB_DELETE);
  report(" --- NB CREATE : " + NB_CREATE);
  report("IMPORT EXCEL END : " + new Date().toISOString());

  const to = process.env.ENV == "prod" ? TO_EMAIL : TO_EMAIL_DEV;
  const params = {
    Destination: {
      ToAddresses: to,
    },
    Message: {
      Body: {
        Text: { Data: getReport() },
      },
      Subject: { Data: "RAPPORT import Excel : " + new Date().toISOString() },
    },
    Source: "rapport@wabap.fr",
  };

  try {
    await new AWS.SES({ region: process.env.REGION }).sendEmail(params).promise();
    console.log(">>>> SEND EMAIL TO [", to, "] : OK");
  } catch (error) {
    console.log(">>>> ERROR SEND EMAIL TO [", to, "] : ERREUR=[", error, "] : ", error.stack);
  }
}

function getReport() {
  return REPORT;
}

// Fonctions pour gérer les abonnés
async function getMissions(clientName) {
  const rep = await docClient
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
  const missions = rep.Items ?? [];
  const mapMissions = {};
  missions.forEach((m) => {
    mapMissions[cleanSecteurName(m.name)] = m.id;
  });
  return mapMissions;
}

async function getSubscriberByNumabo(numabo) {
  const result = await docClient
    .query({
      TableName: `Subscriber-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
      IndexName: "byNumabo",
      KeyConditionExpression: "#n = :n",
      ExpressionAttributeNames: { "#n": "numabo" },
      ExpressionAttributeValues: { ":n": numabo },
    })
    .promise();
  return result.Items[0];
}

async function getNewSub(excelSub, missions, clientName) {
  const newSub = {
    id: crypto.randomUUID(),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    nb: 1,
    type: "subscriber",
    __typename: "Subscriber",
    name: excelSub["nom PDV"],
    numabo: "FDJ"+excelSub["N° PDV"],
    unsubscribed: false,
    owner: clientName,
  };

  // Ajouter l'adresse
  const address = `${excelSub["Rue"]} ${excelSub["Adresse"]}, ${excelSub["CP"]} ${excelSub["Ville"]}`;
  if (address) newSub.address = address;

  // Ajouter les numéros de téléphone
  const phone1 = excelSub["Numéro"];
  if (phone1) newSub.phone1 = phone1;

  // Ajouter le secteur et l'ID de mission
  const secteur = excelSub["Mission"];
  if (secteur) {
    newSub.secteur = secteur;
    const idMission = missions[cleanSecteurName(secteur)];
    if (idMission) newSub.missionSubscribersId = idMission;
  }

  // Ajouter les instructions de livraison
  const instructions = excelSub["consigne liv"];
  if (instructions) newSub.instructions = instructions;

  // Ajouter les coordonnées GPS si disponibles
  const gps = excelSub["GPS"];
  if (gps) {
    const [latitude, longitude] = gps.split(",");
    newSub.latitude = cleanCoordinate(latitude);
    newSub.longitude = cleanCoordinate(longitude);
  } else if (address) {
    // Si aucune coordonnée GPS n'est fournie, utiliser le géocoding
    const geocoding = await getGeocoding(address);
    if (geocoding) {
      newSub.latitude = geocoding.lat;
      newSub.longitude = geocoding.lng;
    }
  }

  return newSub;
}

async function getUpdatedSub(excelSub, dbSub, missions) {
  const updatedSub = {};

  // Mettre à jour le nom
  const name = excelSub["nom PDV"];
  if (name !== dbSub.name) updatedSub.name = name;

  // Mettre à jour l'adresse
  const address = `${excelSub["Rue"]} ${excelSub["Adresse"]}, ${excelSub["CP"]} ${excelSub["Ville"]}`;
  if (address !== dbSub.address) {
    updatedSub.address = address;

    // Si aucune coordonnée GPS n'est fournie, utiliser le géocoding
    const gps = excelSub["GPS"];
    if (!gps) {
      const geocoding = await getGeocoding(address);
      if (geocoding) {
        updatedSub.latitude = geocoding.lat;
        updatedSub.longitude = geocoding.lng;
      }
    }
  }

  // Mettre à jour le numéro de téléphone
  const phone1 = excelSub["Numéro"];
  if (phone1 !== dbSub.phone1) updatedSub.phone1 = phone1;

  // Mettre à jour le secteur et l'ID de mission
  const secteur = excelSub["Mission"];
  if (secteur !== dbSub.secteur) {
    updatedSub.secteur = secteur;
    const idMission = missions[cleanSecteurName(secteur)];
    if (idMission !== dbSub.missionSubscribersId) {
      updatedSub.missionSubscribersId = idMission;
    }
  }

  // Mettre à jour les instructions de livraison
  const instructions = excelSub["consigne liv"];
  if (instructions !== dbSub.instructions) updatedSub.instructions = instructions;

  // Mettre à jour les coordonnées GPS si fournies
  const gps = excelSub["GPS"];
  if (gps) {
    const [latitude, longitude] = gps.split(",");
    if (latitude !== dbSub.latitude) updatedSub.latitude = cleanCoordinate(latitude);
    if (longitude !== dbSub.longitude) updatedSub.longitude = cleanCoordinate(longitude);
  }

  // Si aucune mise à jour n'est nécessaire, retourner null
  if (Object.keys(updatedSub).length === 0) return null;

  // Ajouter les champs obligatoires
  updatedSub.id = dbSub.id;
  updatedSub.updatedAt = new Date().toISOString();
  return updatedSub;
}

function getUnsubscribedSub(dbSub) {
  return {
    id: dbSub.id,
    unsubscribed: true,
    missionSubscribersId: null,
  };
}

async function createSub(sub) {
  await docClient
    .put({
      TableName: `Subscriber-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
      Item: sub,
    })
    .promise();
}

async function updateSub(sub) {
  const updateExpression = [];
  const expressionAttributeValues = {};
  const expressionAttributeNames = {};

  for (const [key, value] of Object.entries(sub)) {
    if (key !== "id" && key !== "updatedAt") {
      updateExpression.push(`#${key} = :${key}`);
      expressionAttributeNames[`#${key}`] = key;
      expressionAttributeValues[`:${key}`] = value;
    }
  }

  if (updateExpression.length === 0) return;

  await docClient
    .update({
      TableName: `Subscriber-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
      Key: { id: sub.id },
      UpdateExpression: "SET " + updateExpression.join(", "),
      ExpressionAttributeNames: expressionAttributeNames,
      ExpressionAttributeValues: expressionAttributeValues,
    })
    .promise();
}

// Fonctions utilitaires supplémentaires
function cleanCoordinate(str) {
  return str?.replace(/[^-.0-9]/g, "");
}

function cleanSecteurName(str) {
  return str?.toLowerCase().replace(/\./g, "") ?? "";
}

function safeLength(obj) {
  if (Array.isArray(obj)) return obj.length;
  if (typeof obj === "object") return Object.keys(obj).length;
  return -1;
}
/* eslint-disable no-undef */
const AWS = require("aws-sdk");
const { getSecret } = require("./secrets");
const docClient = new AWS.DynamoDB.DocumentClient();
const crypto = require("crypto");
const axios = require("axios");
const moment = require("moment-timezone");
require("moment/locale/fr");

const API_WABAP_GRAPHQLAPIIDOUTPUT = process.env.ENV == "prod" ? "nfdn7djf2fcbdjz44rvjidtaf4" : "zjcggzi525bflmgm35w7dji5ui";//TODO : fix

/**
 * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
 */
exports.handler = async (event) => {
  console.log(`SATART LAMBDA createTournee : ${JSON.stringify(event)}`);

  if (!event.missionId) {
    console.error("Error create tournee 400 : Invalid input");
    return {
      statusCode: 400,
      body: JSON.stringify({ error: "Invalid input" }),
    };
  }

  // 1. Create tournee
  moment.locale("fr");
  const mission = await getMission(event.missionId);
  var createForDate = moment().tz(mission.startTimeZone);
  if (event.createForTomorrow == true) createForDate.add(1, "days");
  const idTournee = crypto.randomUUID();
  const newTournee = {
    id: idTournee,
    name: mission.name + " du " + createForDate.format("dddd D MMMM"),
    status: "PENDING",
    startName: mission.startName,
    startLongitude: mission.startLongitude,
    startLatitude: mission.startLatitude,
    livreurID: mission.livreurID,
    missionTourneeId: event.missionId,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    owner: mission.owner,
  };
  try {
    const paramsTournee = {
      TableName: `Tournee-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
      Item: newTournee,
    };
    console.log(`PUT TOURNEE : ${JSON.stringify(paramsTournee)}`);
    await docClient.put(paramsTournee).promise();

    // 2. calcule ordre optimal des colis avec ROUTIFIC
    const subscribers = await getAllSubscribers(mission.id);
    console.log(">> subscribers.length=", safeLength(subscribers));
    const subscribersWithLocation = subscribers.filter(
      (subscriber) =>
        subscriber.latitude != undefined && subscriber.longitude != undefined
    );
    console.log(
      ">> subscribersWithLocation.length=",
      safeLength(subscribersWithLocation)
    );

    const routexl = await getRouteXL(mission, subscribersWithLocation);
    const idIndex = {};
    Object.keys(routexl.route).forEach((key, index) => {
      idIndex[routexl.route[key].name] = index;
    });
    subscribersWithLocation.sort((s1, s2) => {
      return idIndex[s1.id] - idIndex[s2.id];
    });

    var distanceTotal = 0;
    var durationTotal = 0;
    var nbColis = 0;
    newTournee.colis = {};
    newTournee.colis.items = [];
    var previousLocation = {
      lat: mission.startLatitude,
      lng: mission.startLongitude,
    };
    for (const [index, subscriber] of subscribersWithLocation.entries()) {
      try {
        // 3. Create colis status
        if (
          subscriber.latitude == undefined ||
          subscriber.longitude == undefined
        ) {
          throw new Error("No location for subscriber = [", subscriber.id, "]");
        }

        // 4. Create colis
        console.log(`START CREATE COLIS with nb=[${subscriber.nb}]`);
        for (let i = 0; i < subscriber.nb; i++) {
          const googleRep = await getRoutePolyline(
            previousLocation.lat,
            previousLocation.lng,
            subscriber.latitude,
            subscriber.longitude
          );
          const polyline = i == 0 ? googleRep.data.routes[0].overview_polyline.points : "";
          const distance = i == 0 ? googleRep.data.routes[0].legs[0].distance.value : 0;
          const duration = i == 0 ? googleRep.data.routes[0].legs[0].duration.value : 0;
          distanceTotal += distance;
          durationTotal += duration + 60;//add 1min for each colis
          const newColis = {
            id: crypto.randomUUID(),
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            position: index + 1,
            subscriberColisId: subscriber.id,
            tourneeColisId: idTournee,
            polyline: polyline,
            distance: distance,
            duration: duration,
            address: subscriber.address,
            longitude: subscriber.longitude,
            latitude: subscriber.latitude,
            subscriberName: subscriber.name,
            owner: mission.owner,
          };

          const newColisStatus = {
            id: crypto.randomUUID(),
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            colisLogsId: newColis.id,
            status: "PENDING",
            owner: mission.owner,
          };
          console.log(`PUT STATUS_COLIS : ${JSON.stringify(newColisStatus)}`);
          await docClient
            .put({
              TableName: `ColisStatus-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
              Item: newColisStatus,
            })
            .promise();
          console.log(`PUT STATUS_COLIS OK`);

          newColis.lastStatus = newColisStatus;
          newColis.colisLastStatusId = newColisStatus.id;
          newTournee.colis.items.push(newColis);
          console.log(`PUT COLIS : ${JSON.stringify(newColis)}`);
          await docClient
            .put({
              TableName: `Colis-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
              Item: newColis,
            })
            .promise();

          previousLocation = {
            lat: subscriber.latitude,
            lng: subscriber.longitude,
          };
          nbColis++;
        }
      } catch (error) {
        console.log("ERROR PUT COLIS :", error);
      }
    }

    // 6. Update tournee
    newTournee.distance = distanceTotal;
    newTournee.duree = durationTotal;
    const params = {
      TableName: `Tournee-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
      Key: { id: newTournee.id },
      UpdateExpression: "set distance = :di, duree = :du, nbColis = :nb",
      ExpressionAttributeValues: {
        ":di": distanceTotal,
        ":du": durationTotal,
        ":nb": nbColis,
      },
    };
    console.log(`UPDATE TOURNEE : ${JSON.stringify(params)}`);
    await docClient.update(params).promise();

    return {
      statusCode: 200,
      body: JSON.stringify(newTournee),
    };
  } catch (error) {
    console.error("Error create tournee:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Failed to create tournee",
        code: error.code,
      }),
    };
  }
};

async function getAllSubscribers(missionId) {
  console.log(`REQ : getAllSubscribers(${missionId})`);
  const params = {
    TableName: `Subscriber-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
    FilterExpression:
      "missionSubscribersId = :missionId AND unsubscribed = :unsubscribed",
    ExpressionAttributeValues: {
      ":missionId": missionId,
      ":unsubscribed": false,
    },
    Limit: 1000,//TODO ; a corriger, si plus de 1000 subscriber, alors prendra pas tout
  };
  console.log(`REQ : ${JSON.stringify(params)}`);
  try {
    const rep = await docClient.scan(params).promise();
    return rep.Items;
  } catch (error) {
    console.error("Error get all subscribers :", error);
    return null;
  }
}

async function getMission(missionId) {
  const params = {
    TableName: `Mission-${API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
    Key: {
      id: missionId,
    },
  };
  console.log(`REQ : ${JSON.stringify(params)}`);
  try {
    const rep = await docClient.get(params).promise();
    console.log(`REP : ${JSON.stringify(rep)}`);
    return rep.Item;
  } catch (error) {
    console.error("Error get mission (" + missionId + ") :", error);
    return null;
  }
}

async function getRouteXL(mission, subscribers) {
  var url = "https://api.routexl.com/tour/";

  console.log(
    ">>> getRouteXL : ",
    mission.id,
    " nbColis=",
    safeLength(subscribers)
  );

  const headers = {
    'Authorization': `Basic ${await getSecret("ROUTEXL_AUTH")}`,
    'Content-Type': 'application/x-www-form-urlencoded'
  };

  if (subscribers.length === 0) {
    console.error("Error create tournee 400 : None colis");
    throw new Error("None colis");
  }

  if (
    mission.startLatitude === undefined ||
    mission.startLongitude === undefined
  ) {
    console.error("Error create tournee 400 : No location for mission");
    throw new Error("No location for mission");
  }

  const data = [];
  data.push({
    address: "start",
    lat: mission.startLatitude,
    lng: mission.startLongitude,
  });

  for (const subscriber of subscribers) {
    if (
      subscriber.latitude !== undefined &&
      subscriber.longitude !== undefined
    ) {
      data.push({
        address: subscriber.id,
        lat: subscriber.latitude,
        lng: subscriber.longitude,
      });
    } else {
      console.error(
        "WRNING subscriber ignore because no location : " +
          JSON.stringify(subscriber)
      );
    }
  }
  //only because the ending is obligatory, will be removed after
  data.push({
    address: "end",
    lat: mission.startLatitude,
    lng: mission.startLongitude,
  });

  console.log(`ROUTEXL url : ${url} - data : locations=${JSON.stringify(data)}`);

  try {
    const response = await axios.post(url, `locations=${JSON.stringify(data)}`, { headers: headers });
    console.log("ROUTEXL Response:", response.data);
    return response.data;
  } catch (error) {
    console.error("ERROR ROUTEXL request:", error);
    throw error;
  }
}

async function getRoutePolyline(startLat, startLng, endLat, endLng) {
  const endpoint = `https://maps.googleapis.com/maps/api/directions/json?origin=${startLat},${startLng}&destination=${endLat},${endLng}&mode=driving&key=${await getSecret("GOOGLE_MAPS_API_KEY")}`;

  try {
    console.log(`GET GOOGLE API ROUTE : ${endpoint.replace(/key=[^&]+/, "key=***")}`);
    return await axios.get(endpoint);
  } catch (error) {
    console.error("ERROR GOOGLE API ROUTE :", error);
    throw error;
  }
}

function safeLength(array) {
  return Array.isArray(array) ? array.length : -1;
}

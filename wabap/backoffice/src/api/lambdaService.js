import AWS from "aws-sdk";
import { Auth } from "@aws-amplify/auth";
import { ENV } from "@/util/const";

export const updateMissionSubscribersId = async (json) => {
  const params = {
    FunctionName: `updateMissionSubscribersId-${ENV}`,
    InvocationType: "RequestResponse",
    Payload: JSON.stringify(json),
  };
  console.log(">>> LAMBDA CALL : ", params);
  return new Promise((resolve, reject) => {
    new AWS.Lambda().invoke(params, (error, data) => {
      if (error || data.FunctionError || data.StatusCode !== 200) {
        console.error("ERROR calling Lambda", error);
        reject(error);
      } else {
        console.log("OK calling Lambda", data);
        resolve(data.Payload);
      }
    });
  });
};

export const createTournee = async (missionId) => {
  const params = {
    FunctionName: `createTournee-${ENV}`,
    InvocationType: "RequestResponse",
    Payload: JSON.stringify({ missionId: missionId }),
  };
  console.log(">>> LAMBDA CALL : ", params);
  return new Promise((resolve, reject) => {
    new AWS.Lambda().invoke(params, (error, data) => {
      if (error || data.FunctionError || data.StatusCode !== 200) {
        console.error("ERROR calling Lambda", error);
        reject(error);
      } else {
        console.log("OK calling Lambda", data);
        resolve(JSON.parse(data.Payload));
      }
    });
  });
};


export const importCSV = async (json) => {
  const params = {
    FunctionName: `importCSV-${ENV}`,
    InvocationType: "RequestResponse",
    Payload: JSON.stringify(json),
  };
  console.log(">>> LAMBDA CALL : ", params);
  return new Promise((resolve, reject) => {
    new AWS.Lambda().invoke(params, (error, data) => {
      if (error || data.FunctionError || data.StatusCode !== 200) {
        console.error("ERROR calling Lambda", error);
        reject(error);
      } else {
        console.log("OK calling Lambda", data);
        resolve(data.Payload);
      }
    });
  });
};

export const importExcel = async (json) => {
  const params = {
    FunctionName: `importExcel-${ENV}`,
    InvocationType: "RequestResponse",
    Payload: JSON.stringify(json),
  };
  console.log(">>> LAMBDA CALL : ", params);
  return new Promise((resolve, reject) => {
    new AWS.Lambda().invoke(params, (error, data) => {
      if (error) {
        console.error("ERROR calling Lambda", error);
        reject(error);
      } else if (data.FunctionError) {
        console.error("Lambda Function Error", data.FunctionError);
        reject(data.FunctionError);
      } else if (data.StatusCode !== 200) {
        console.error("Unexpected status code:", data.StatusCode);
        console.error("Response data:", data);
        reject(new Error(`Unexpected response code: ${data.StatusCode}`));
      }  else {
        console.log("OK calling Lambda", data);
        resolve(data.Payload);
      }
    });
  });
};
export const usersLambda = async () => {
  const user = await Auth.currentAuthenticatedUser();
  const params = {
    FunctionName: `usersLambda-${ENV}`,
    InvocationType: "RequestResponse",
    Payload: JSON.stringify({ accessToken: user.signInUserSession.accessToken.jwtToken }),
  };
  console.log(">>> LAMBDA CALL : ", params);
  return new Promise((resolve, reject) => {
    new AWS.Lambda().invoke(params, (error, data) => {
      if (error || data.FunctionError || data.StatusCode !== 200) {
        console.error("ERROR calling Lambda", error);
        reject(error);
      } else {
        console.log("OK calling Lambda", data);
        resolve(data.Payload);
      }
    });
  });
};


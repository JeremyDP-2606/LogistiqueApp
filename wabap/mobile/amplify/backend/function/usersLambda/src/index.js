/* eslint-disable no-undef */
const AmazonCognitoIdentity = require('amazon-cognito-identity-js');


/**
 * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
 */
exports.handler = async (event) => {
  console.log(`USERS LAMBDA EVENT: ${JSON.stringify(event)}`);

  const accessToken = event.accessToken;
  if (!accessToken) throw new Error("No access token");

  const poolData =
    process.env.ENV == "prod"
      ? {
          UserPoolId: "us-east-1_c5SbPwJEZ",
          ClientId: "6g7521kgouj9fjsg9aibi4h650",
        }
      : {
          UserPoolId: "us-east-1_04eESPTU3",
          ClientId: "7gnmlbods8hp2rlb4bmbc7uqd4",
        };

  const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

  const params = {
    Storage: accessToken,
    Pool : userPool
  };

  const cognitoUser = new AmazonCognitoIdentity.CognitoUser();

  cognitoUser.getUserAttributes(params, (err, result) => {
    if (err) {
      console.error(err);
      callback(err);
    } else {
      console.log(result);
      // Vous avez maintenant les attributs de l'utilisateur
      callback(null, "Succès");
    }
  });

  return {
    statusCode: 200,
    body: JSON.stringify("Hello from Lambda!"),
  };
};

/* eslint-disable no-undef */
const AWS = require('aws-sdk');
const cognito = new AWS.CognitoIdentityServiceProvider();

/**
 * @type {import('@types/aws-lambda').APIGatewayProxyHandler}
 */
exports.handler = async (event) => {
    console.log(`START LAMBDA listUsers : ${JSON.stringify(event)}`);

    const userPoolId = process.env.ENV == "prod" ? "us-east-1_c5SbPwJEZ" : "us-east-1_04eESPTU3";
    const params = {
        UserPoolId: userPoolId,
        Limit: 50
    };
    
    try {
        const data = await cognito.listUsers(params).promise();
        const rep = transformUsersData(data);
        return {
            statusCode: 200,
            body: JSON.stringify(rep),
        };
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify(error),
        };
    }
};

function transformUsersData(usersData) {
    return usersData.Users.map(user => {
        let transformedUser = {};
        
        transformedUser.username = user.Username;

        user.Attributes.forEach(attribute => {
            if (attribute.Name === 'sub') {
                transformedUser.sub = attribute.Value;
            }
            if (attribute.Name === 'given_name') {
                transformedUser.given_name = attribute.Value;
            }
            if (attribute.Name === 'family_name') {
                transformedUser.family_name = attribute.Value;
            }
            if (attribute.Name === 'custom:clientName') {
                transformedUser.client_name = attribute.Value;
            }
        });
        
        return transformedUser;
    });
}

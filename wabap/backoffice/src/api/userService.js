import AWS from "aws-sdk";
import config from "@/aws-exports";
import { getClientName } from "@/util/auth";

export const getUsers = async () => {
  try {
    const clientName = await getClientName();
    const response = await new AWS.CognitoIdentityServiceProvider()
      .listUsers({
        UserPoolId: config.aws_user_pools_id,
        Limit: 60,
      })
      .promise();
    //TODO : securiser, server-side
    return clientName
      ? response.Users.filter((user) =>
          user.Attributes.find(
            (att) =>
              att.Name === "custom:clientName" && att.Value === clientName
          )
        )
      : response.Users;
    
  } 
  catch (error) {
    console.error(">>> Error : SERVICE Users", error);
    throw error;
  }
};

export const getUser = async (sub) => {
  try {
    const response = await new AWS.CognitoIdentityServiceProvider()
      .listUsers({
        UserPoolId: config.aws_user_pools_id,
        Filter: `sub = "${sub}"`,
      })
      .promise();

    return response.Users?.[0] || null;
  } catch (error) {
    console.error(">>> Error : SERVICE User", error);
    throw error;
  }
};

export const getGroupUser = async (userName) => {
  if (userName == undefined) return [];
  try {
    const cognitoISP = new AWS.CognitoIdentityServiceProvider();
    const groupsResponse = await cognitoISP
      .adminListGroupsForUser({
        Username: userName,
        UserPoolId: config.aws_user_pools_id,
      })
      .promise();
    return groupsResponse.Groups?.map((group) => group.GroupName) || null;
  } catch (error) {
    console.error(">>> Error : SERVICE get GROUP", error);
    throw error;
  }
};

export const addUser = async (user) => {
  const { username, firstName, lastName, email, password, group, clientName, deliveryChecking } =
    user;
  try {
    const authClientName = await getClientName();
    const cognitoISP = new AWS.CognitoIdentityServiceProvider();
    await cognitoISP
      .adminCreateUser({
        UserPoolId: config.aws_user_pools_id,
        Username: username,
        UserAttributes: [
          { Name: "family_name", Value: lastName },
          { Name: "given_name", Value: firstName },
          { Name: "email", Value: email },
          { Name: "custom:clientName", Value: authClientName ?? clientName },
          { Name: "custom:deliveryChecking", Value: deliveryChecking ? "true" : "false" },
        ],
        TemporaryPassword: password,
      })
      .promise();

    await cognitoISP
      .adminAddUserToGroup({
        UserPoolId: config.aws_user_pools_id,
        Username: username,
        GroupName: group,
      })
      .promise();
  } catch (error) {
    console.error(">>> Error : SERVICE Add USER", error);
    throw error;
  }
};

export const updateUser = async (oldUser, newUser) => {
  try {
    const authClientName = await getClientName();
    const cognitoISP = new AWS.CognitoIdentityServiceProvider();
    await cognitoISP
      .adminUpdateUserAttributes({
        UserPoolId: config.aws_user_pools_id,
        Username: oldUser.username,
        UserAttributes: [
          { Name: "family_name", Value: newUser.lastName },
          { Name: "given_name", Value: newUser.firstName },
          { Name: "email", Value: newUser.email },
          {
            Name: "custom:clientName",
            Value: authClientName ?? newUser.clientName ?? oldUser.clientName,
          },
          {
            Name:"custom:deliveryChecking",
            Value: newUser.deliveryChecking ? "true" : "false",
          }
        ],
      })
      .promise();

    if (oldUser.group != newUser.group) {
      if (oldUser.group != null) {
        await cognitoISP
          .adminRemoveUserFromGroup({
            UserPoolId: config.aws_user_pools_id,
            Username: oldUser.username,
            GroupName: oldUser.group,
          })
          .promise();
      }

      await cognitoISP
        .adminAddUserToGroup({
          UserPoolId: config.aws_user_pools_id,
          Username: oldUser.username,
          GroupName: newUser.group,
        })
        .promise();
    }
  } catch (error) {
    console.error(">>> Error : SERVICE Add USER", error);
    throw error;
  }
};

export const deleteUser = async (username) => {
  try {
    await new AWS.CognitoIdentityServiceProvider()
      .adminDeleteUser({
        UserPoolId: config.aws_user_pools_id,
        Username: username,
      })
      .promise();
  } catch (error) {
    console.error(">>> Error : SERVICE DELETE User", error);
    throw error;
  }
};

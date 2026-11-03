window.global = window

import "./assets/main.css";
import "@mdi/font/css/materialdesignicons.min.css";

import { createApp } from "vue";
import App from "./App.vue";


const app = createApp(App);

// Router
import router from "./router";
app.use(router);

// Vuetify
import "vuetify/styles";
import { createVuetify } from "vuetify";
import * as components from "vuetify/components";
import * as directives from "vuetify/directives";
import { color } from "@/util/const";
const myCustomLightTheme = {
  dark: false,
  colors: {
    primary: color.primary,
  },
};
app.use(
  createVuetify({
    components,
    directives,
    theme: {
      defaultTheme: "myCustomLightTheme",
      themes: {
        myCustomLightTheme,
      },
    },
  })
);

// AWS
import { Amplify } from "@aws-amplify/core";
import { Auth } from "@aws-amplify/auth";
import config from "./aws-exports";
import AWS from "aws-sdk";
import { isUserAuthenticated } from "@/util/auth";
Amplify.configure(config);
Amplify.configure({
  API: {
      graphql_headers: async () => ({
          'Authorization': (await Auth.currentSession()).getIdToken().getJwtToken()
      })
  }
});
Auth.configure(config);
//authenticating with AWS Cognito
isUserAuthenticated().then((isAuth) => {
  if (isAuth) {
    Auth.currentAuthenticatedUser().then((user) => {
      const { idToken } = user.signInUserSession;
      const cognitoIssuer = `cognito-idp.${config.aws_cognito_region}.amazonaws.com/${config.aws_user_pools_id}`;
      AWS.config.update({
        region: config.aws_project_region,
        credentials: new AWS.CognitoIdentityCredentials({
          IdentityPoolId: config.aws_cognito_identity_pool_id,
          Logins: {
            [cognitoIssuer]: idToken.jwtToken,
          },
        }),
      });
      AWS.config.credentials.getPromise();
    });
  } else {
    AWS.config.update({
      region: config.aws_project_region
    });
  }
});

app.mount("#app");

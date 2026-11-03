<script setup>
import { ref, computed, inject } from "vue";
import { Auth } from "@aws-amplify/auth";
import router from "@/router";
import logo from "@/assets/logo.png";
import { isAuthorized } from "@/util/auth";
import config from "../aws-exports";
import AWS from "aws-sdk";

const showError = inject("showError");
const form = ref(null);
const username = ref("");
const password = ref("");
const showPassword = ref(false);
const btnLoading = ref(false);
const formNewPass = ref(null);
const enableBtnValidateNewPass = ref(false);
const dialogNewPass = ref(null);
const textFieldPass1 = ref(null);
const textFieldPass2 = ref(null);
const rulesUsername = ref([
  (value) => !!value || "Merci de saisir votre Identifiant.",
]);
const rulesPassword = ref([
  (value) => !!value || "Merci de saisir votre mot de passe.",
]);
const rulesNewPassword = ref([
  (value) => (!!value && value.length >= 8) || "8 caractères minimum.",
]);

const login = async () => {
  const { valid } = await form.value.validate();
  if (valid) {
    btnLoading.value = true;

    try {
      const user = await Auth.signIn(username.value, password.value);
      if (user.challengeName === "NEW_PASSWORD_REQUIRED") {
        showError("Nouveau mot de passe requis.");
        dialogNewPass.value = true;
      } else {
        if (await isAuthorized()) {
          const currentUser = await Auth.currentAuthenticatedUser();
          const { idToken } = currentUser.signInUserSession;
          const cognitoIssuer = `cognito-idp.${config.aws_cognito_region}.amazonaws.com/${config.aws_user_pools_id}`;
          AWS.config.update({
            credentials: new AWS.CognitoIdentityCredentials({
              IdentityPoolId: config.aws_cognito_identity_pool_id,
              Logins: {
                [cognitoIssuer]: idToken.jwtToken,
              },
            }),
          });
          await AWS.config.credentials.getPromise();
          router.push("/missions");
        } else {
          showError("Vous n'êtes pas authorisé à accéder à ce site.");
        }
      }
    } catch (error) {
      console.error("Erreur d'authentification :", error);
      switch (error.code) {
        case "UserNotFoundException":
          showError("L'utilisateur n'existe pas.");
          break;
        case "NotAuthorizedException":
          showError("Identifiant ou mot de passe incorrect.");
          break;
        default:
          showError("Une erreur inattendue est survenue. (" + error + ")");
      }
    }

    btnLoading.value = false;
  }
};

const newPass = async () => {
  const { valid } = await formNewPass.value.validate();

  if (valid) {
    try {
      const user = await Auth.signIn(username.value, password.value);
      await Auth.completeNewPassword(user, textFieldPass1.value.value);
      router.push("/missions");
    } catch (error) {
      showError("Une erreur inattendue est survenue. (" + error + ")");
    }
  }
};

const urlLogo = computed(() => {
  return logo;
});

const onConfirmNewPass = (event) => {
  enableBtnValidateNewPass.value =
    event.target.value.length > 2 &&
    textFieldPass1.value.value === textFieldPass2.value.value;
};
</script>

<template>
  <v-container fill-height class="d-flex justify-center align-center">
    <v-card width="400px" class="degrade pa-6 mt-8">
      <v-card-title class="text-center">
        <img width="150" :src="urlLogo" class="ma-4" alt="Logo" />
      </v-card-title>
      <v-card-text>
        <v-form ref="form" @submit.prevent="login">
          <v-row class="px-3">
            <v-col cols="12">
              <v-text-field
                :disabled="btnLoading"
                label="Identifiant"
                v-model="username"
                prepend-inner-icon="mdi-email"
                variant="solo"
                :rules="rulesUsername"
              ></v-text-field>
            </v-col>
            <v-col cols="12">
              <v-text-field
                :disabled="btnLoading"
                label="Mot de passe"
                v-model="password"
                prepend-inner-icon="mdi-lock"
                :append-inner-icon="
                  showPassword ? 'mdi-eye-outline' : 'mdi-eye-off-outline'
                "
                :rules="rulesPassword"
                :type="showPassword ? 'text' : 'password'"
                variant="solo"
                @click:append-inner="showPassword = !showPassword"
              ></v-text-field>
            </v-col>
            <v-col class="text-center" cols="12">
              <v-btn
                :disabled="btnLoading"
                :loading="btnLoading"
                rounded="xl"
                size="large"
                type="submit"
                >Connecter</v-btn
              >
            </v-col>
          </v-row>
        </v-form>
      </v-card-text>
    </v-card>

    <v-dialog v-model="dialogNewPass" width="500">
      <v-form ref="formNewPass" @submit.prevent="newPass">
        <v-card title="Première connexion">
          <v-card-text>
            Vous vous connectez pour la première fois, merci de choisir un mot
            de passe :
            <v-col cols="12" class="pt-8">
              <v-text-field
                label="Mot de passe"
                @input="onConfirmNewPass"
                variant="solo"
                ref="textFieldPass1"
                :rules="rulesNewPassword"
              ></v-text-field>
              <v-text-field
                class="pt-5"
                label="Confirmation mot de passe"
                @input="onConfirmNewPass"
                variant="solo"
                ref="textFieldPass2"
                :rules="rulesNewPassword"
              ></v-text-field>
            </v-col>
          </v-card-text>
          <v-card-actions>
            <v-spacer />
            <v-btn text="Annuler" @click="dialogNewPass = false" />
            <v-btn
              text="Valider"
              :disabled="!enableBtnValidateNewPass"
              type="submit"
            />
          </v-card-actions>
        </v-card>
      </v-form>
    </v-dialog>
  </v-container>
</template>

<style lang="css" scoped>
.v-btn {
  text-transform: none;
}
</style>

<script setup>
import { ref, onMounted, inject, computed } from "vue";
import { color } from "@/util/const";
import { useRoute } from "vue-router";
import { formatError, getAttribute } from "@/util/util";
import { addUser, getUser, getGroupUser, updateUser } from "@/api/userService";
import router from "@/router";
import { getClientName } from "@/util/auth";

const route = useRoute();
const showError = inject("showError");
const userEdit = ref(null);
const listGroup = ref([
  {
    name: "Administrateur",
    id: "admin",
    description:
      "Peut tout supprimer, tout modifier, sur l'applicaiton mobile et le back-office.",
  },
  {
    name: "Livreur",
    id: "livreur",
    description:
      "Peut se connecter uniquement à l'application mobile et consulter ses tournées.",
  },
  {
    name: "Contrôleur",
    id: "client",
    description: "Peut uniquement se connecter et consulter le back-office.",
  },
]);
const userLoading = ref(false);
const btnLoading = ref(false);
const clientName = ref(null);

const form = ref(null);
const modelUsername = ref(null);
const modelFirstName = ref(null);
const modelLastName = ref(null);
const modelClientName = ref(null);
const modelMail = ref(null);
const modelPassword = ref(null);
const modelGroup = ref(null);
const modelAccepted = ref(null);

onMounted(async () => {
  Promise.all([fetchUser(route.params.id)]).then(() => {
    prefillForm(userEdit.value);
  });
  clientName.value = await getClientName();
});

const fetchUser = async (userId) => {
  if (userId == undefined) return;
  try {
    userLoading.value = color.primary;
    const resultat = await getUser(userId);
    if (resultat != null) {
      const groups = await getGroupUser(resultat.Username);
      userEdit.value = {
        username: resultat.Username,
        firstName: getAttribute(resultat, "given_name", null),
        lastName: getAttribute(resultat, "family_name", null),
        email: getAttribute(resultat, "email", null),
        clientName: getAttribute(resultat, "custom:clientName", null),
        deliveryChecking: getAttribute(resultat, "custom:deliveryChecking", null),
        group: groups.length > 0 ? groups[0] : null,
      };
    }
  } catch (error) {
    showError("Erreur de chargement user (" + formatError(error) + ")");
  } finally {
    userLoading.value = false;
  }
};

const prefillForm = async (user) => {
  if (user !== null) {
    modelUsername.value = user.Username;
    if (user.firstName !== null) modelFirstName.value = user.firstName;
    if (user.lastName !== null) modelLastName.value = user.lastName;
    if (user.clientName !== null) modelClientName.value = user.clientName;
    if (user.email !== null) modelMail.value = user.email;
    if (user.group !== null) {
      modelGroup.value = listGroup.value.find((g) => g.id === user.group);
    }
    if (user.deliveryChecking !==null) {
      user.deliveryChecking === "true" ? modelAccepted.value = true : false;
    }
  }
};

const textTitle = computed(() => {
  return userEdit.value == null
    ? "AJOUTER UN UTILISATEUR"
    : "METTRE À JOUR L'UTILISATEUR : " + userEdit.value.username;
});
const textBtnSubmit = computed(() => {
  return userEdit.value == null
    ? "Créer l'utilisateur"
    : "Mettre à jour l'utilisateur";
});

const rulesUsername = ref([
  (value) => !!value || "Merci de choisir un Pseudo.",
]);
const rulesFirstName = ref([
  (value) => !!value || "Merci de choisir un Prénom.",
]);
const rulesClientName = ref([
  (value) => !!value || "Merci de choisir un nom de client.",
]);
const rulesLastName = ref([(value) => !!value || "Merci de choisir un Nom."]);
const rulesMail = ref([
  (v) =>
    (!!v && /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/.test(v)) ||
    "Saisissez une adresse mail valide.",
]);
const rulesPassword = ref([
  (value) => value?.length >= 8 || "Au moins 8 caractères.",
]);
const rulesGroup = ref([
  (value) => !!value || "Choisissez un type d'utilisateur.",
]);

const formSubmit = async () => {
  var { valid } = await form.value.validate();

  if (valid) {
    try {
      btnLoading.value = true;

      if (userEdit.value == null) {
        const user = {
          username: modelUsername.value,
          firstName: modelFirstName.value,
          lastName: modelLastName.value,
          clientName: modelClientName.value,
          email: modelMail.value,
          password: modelPassword.value,
          group: modelGroup.value.id,
          deliveryChecking : modelAccepted.value,
        };
        await addUser(user);
        router.push("/users/");
      } else {
        const user = {
          firstName: modelFirstName.value,
          lastName: modelLastName.value,
          clientName: modelClientName.value,
          email: modelMail.value,
          group: modelGroup.value.id,
          deliveryChecking : modelAccepted.value,
        };
        await updateUser(userEdit.value, user);
        router.push("/user/" + route.params.id);
      }
    } catch (error) {
      showError(
        "Erreur lors de la création de l'utilisateur (" +
          formatError(error) +
          ")"
      );
    } finally {
      btnLoading.value = false;
    }
  }
};

const hintGroup = computed(() => {
  return modelGroup.value != null ? modelGroup.value.description : null;
});
</script>

<template>
  <div class="loader" v-show="userLoading">
    <v-progress-circular
      :size="50"
      :width="5"
      indeterminate
      color="primary"
    ></v-progress-circular>
  </div>
  <div class="content" v-show="!userLoading">
    <h1 class="pa-8">{{ textTitle }}</h1>

    <v-card
      :disabled="userLoading"
      :loading="userLoading"
      elevation="3"
      class="ma-8 pa-8"
    >
      <v-form ref="form" @submit.prevent="formSubmit">
        <v-row v-if="userEdit == null">
          <v-col class="text-form" cols="12">
            <p>Pseudo :</p>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              label="Pseudo"
              v-model="modelUsername"
              :rules="rulesUsername"
              variant="solo"
            ></v-text-field>
          </v-col>
        </v-row>
        <v-row v-if="userEdit == null">
          <v-col class="text-form" cols="12">
            <p>Mot de passe :</p>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              label="Mot de passe"
              v-model="modelPassword"
              :rules="rulesPassword"
              variant="solo"
              type="password"
            ></v-text-field>
          </v-col>
        </v-row>
        <v-row v-if="clientName == null">
          <v-col class="text-form" cols="12">
            <p>Nom du client :</p>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              label="nom du client"
              v-model="modelClientName"
              :rules="rulesClientName"
              variant="solo"
            ></v-text-field>
          </v-col>
        </v-row>
        <v-row>
          <v-col class="text-form" cols="12">
            <p>Type de compte :</p>
          </v-col>
          <v-col cols="12" md="6">
            <v-select
              v-model="modelGroup"
              label="Rôle"
              :items="listGroup"
              :hint="hintGroup"
              item-title="name"
              variant="solo"
              return-object
              :rules="rulesGroup"
            ></v-select>
          </v-col>
        </v-row>
        <v-row>
          <v-col class="text-form" cols="12">
            <p>Prénom :</p>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              label="Prénom"
              v-model="modelFirstName"
              :rules="rulesFirstName"
              variant="solo"
            ></v-text-field>
          </v-col>
        </v-row>
        <v-row>
          <v-col class="text-form" cols="12">
            <p>Nom :</p>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              label="Nom"
              v-model="modelLastName"
              :rules="rulesLastName"
              variant="solo"
            ></v-text-field>
          </v-col>
        </v-row>
        <v-row>
          <v-col class="text-form" cols="12">
            <p>Adresse mail :</p>
          </v-col>
          <v-col cols="12" md="6">
            <v-text-field
              label="Mail"
              v-model="modelMail"
              :rules="rulesMail"
              variant="solo"
            ></v-text-field>
          </v-col>
        </v-row>
        <v-row >
          <v-col class="text-form" cols="12">
            <p>Contrôle de livraison : </p>
            <v-checkbox
              v-model="modelAccepted"
              :rules="RulesChecked"
              variant="solo"
            ></v-checkbox>
          </v-col>
          
        </v-row>

        <v-row>
          <v-col class="text-end">
            <v-btn
              :loading="btnLoading"
              rounded="xl"
              size="large"
              type="submit"
              variant="outlined"
              :color="color.primary"
              >{{ textBtnSubmit }}</v-btn
            >
          </v-col>
        </v-row>
      </v-form>
    </v-card>
  </div>
</template>


<style scoped>
.loader {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100%;
  height: 100%;
}
</style>
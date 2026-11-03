<script setup>
import { ref, onMounted, inject, computed, watch } from "vue";
import { color } from "@/util/const";
import { isFloat, formatError } from "@/util/util";
import { getUsers } from "@/api/userService";
import { getSubscribersWithoutMission } from "@/api/subscriberService";
import GoogleAutocomplete from "@/components/GoogleAutocomplete.vue";
import { updateMissionSubscribersId } from "@/api/lambdaService";
import router from "@/router";
import { useRoute } from "vue-router";
import { missionGet, missionCreate } from "@/api/missionService";
import { missionUpdate } from "../api/missionService";
import { getAttribute } from "@/util/util";
import moment from "moment";
import { getClientName } from "@/util/auth";

const route = useRoute();
const showError = inject("showError");
const clientNanme = ref(null);
const listLivreur = ref([]);
const listSubscriber = ref([]);
const userLoading = ref(false);
const subscriberLoading = ref(false);
const loadMoreSubLoading = ref(false);
const cardLoading = ref(false);
const btnLoading = ref(false);
const googleAutocomplete = ref(null);

const missionEdit = ref(null);
const form = ref(null);
const modelName = ref(null);
const modelNameClient = ref(null);
const modelLivreur = ref(null);
const modelSubscribers = ref(null);
const modelToggleDays = ref({});
const modelCheckWithRepeat = ref(true);
const modelCheckAllDays = ref(false);
const modelCheckDayBefore = ref(false);
const modelHour = ref(null);
const modelMinute = ref(null);
const selectedStartName = ref(null);
const modelLatitude = ref(null);
const modelLongitude = ref(null);
const errorDays = ref(false);
const btnMapCoorEnable = ref(false);
const hours = Array.from({ length: 24 }, (_, i) => i);
const minutes = Array.from({ length: 12 }, (_, i) => i * 5);
const modelTimeZone = ref("America/Martinique");
const autoSelectSub = ref(true);
const users = ref(null);
const deliveryCheckingAttr = ref(false);
onMounted(async () => {
  Promise.all([
    fetchLivreurs(),
    fetchSubscribers(route.params.id),
    fetchMission(route.params.id),
  ]).then(() => {
    prefillForm(missionEdit.value);
  });
  clientNanme.value = await getClientName();
  users.value = getUsers()
});

const fetchLivreurs = async () => {
  try {
    userLoading.value = color.primary;
    const users = await getUsers();

    const list = users.map((user) => ({
      id: getAttribute(user, "sub"),
      title: user.Username,
      subtitle: getAttribute(user, "email"),
    }));

    listLivreur.value = list;
  } catch (error) {
    showError("Erreur de chargement Livreurs (" + formatError(error) + ")");
  } finally {
    userLoading.value = false;
  }
};

const listSubscriberNextToken = ref(null);
const fetchSubscribers = async (missionId) => {
  try {
    subscriberLoading.value = color.primary;
    const resultat = await getSubscribersWithoutMission(
      missionId,
      listSubscriberNextToken.value
    );
    const list = resultat.items.map((subscriber) => ({
      id: subscriber.id,
      title:
        subscriber.name +
        (subscriber.secteur ? " (" + subscriber.secteur + ")" : ""),
      subtitle: subscriber.address,
      secteur: subscriber.secteur,
    }));
    if (listSubscriber.value == null) listSubscriber.value = list;
    else listSubscriber.value = listSubscriber.value.concat(list);
    listSubscriberNextToken.value = resultat.nextToken;
    selectSubByName();
  } catch (error) {
    showError("Erreur de chargement subscribers  (" + formatError(error) + ")");
  } finally {
    subscriberLoading.value = false;
  }
};

const fetchMission = async (id) => {
  if (id === undefined) return;
  try {
    cardLoading.value = color.primary;
    missionEdit.value = await missionGet(id);
  } catch (error) {
    console.error(">>> Error : MISSION", error);
    showError("Erreur de chargement  (" + formatError(error) + ")");
  }
  cardLoading.value = false;
};

const prefillForm = async (mission) => {
  if (mission === null) {
    modelHour.value = 22;
    modelMinute.value = 0;
    modelCheckDayBefore.value = true;
  } else {
    autoSelectSub.value = false;
    modelName.value = mission.name;
    modelNameClient.value = mission.owner;
    modelLivreur.value = listLivreur.value.find(
      (livreur) => livreur.id === mission.livreurID
    );
    const listSub = mission.subscribers.items.map((subscriber) => ({
      id: subscriber.id,
      title:
        subscriber.name +
        (subscriber.secteur ? " (" + subscriber.secteur + ")" : ""),
      subtitle: subscriber.address,
      secteur: subscriber.secteur,
    }));
    modelSubscribers.value = listSub;
    if (mission.daysOfWeek) {
      modelToggleDays.value = mission.daysOfWeek.reduce(
        (acc, currentValue, index) => {
          if (currentValue) acc.push(index);
          return acc;
        },
        []
      );
    }
    if (mission.startTime) {
      modelHour.value = Math.trunc(mission.startTime);
      modelMinute.value = Math.round(
        (mission.startTime - Math.trunc(mission.startTime)) * 60
      );
    }
    if (mission.startTimeZone) {
      modelTimeZone.value = mission.startTimeZone;
    }
    modelCheckWithRepeat.value = mission.daysOfWeek != null && mission.startTime != null && mission.startTimeZone != null;
    modelCheckDayBefore.value = mission.generateDayBefore;
    modelLatitude.value = mission.startLatitude;
    modelLongitude.value = mission.startLongitude;
    googleAutocomplete.value.update(mission.startName);

    //Inscriptions
    for (const livreur of listLivreur.value) {
      let inscription = mission.inscriptions.items.find(
        (i) => i.livreurID === livreur.id
      );
      if (inscription != null) {
        livreur.inscriptionDate = inscription.createdAt;
        livreur.subtitle =
          "Inscrit le " +
          moment(inscription.createdAt).format("DD/MM/YY [à] HH[h]mm");
      } else {
        livreur.subtitle = "Pas inscrit";
      }
    }
    listLivreur.value = listLivreur.value.sort(function (i1, i2) {
      return (
        new Date(i1.inscriptionDate ?? new Date().toISOString()) -
        new Date(i2.inscriptionDate ?? new Date().toISOString())
      );
    });

    const num = ["❶", "❷", "❸", "❹", "❺", "❻", "❼", "❽", "❾"];
    for (let i = 1; i < listLivreur.value.length + 1; i++) {
      const livreur = listLivreur.value[i - 1];
      if (livreur.inscriptionDate != undefined) {
        const n = i < num.length + 1 ? num[i - 1] : i + ")";
        livreur.title = n + " " + livreur.title;
      }
    }
  }
};

const getAddressData = (resultat) => {
  modelLatitude.value = resultat.latitude;
  modelLongitude.value = resultat.longitude;
};

const onAddressChange = (adresse) => {
  selectedStartName.value = adresse.newVal;
};

watch(modelToggleDays, () => {
  errorDays.value = false;
  modelCheckAllDays.value = modelToggleDays.value.length == 7;
});

const watchCoor = () => {
  btnMapCoorEnable.value =
    modelLatitude.value != null && modelLongitude.value != null;
};
watch(modelLatitude, watchCoor);
watch(modelLongitude, watchCoor);

const onAllDaysChanghe = () => {
  modelToggleDays.value = modelCheckAllDays.value ? [] : [0, 1, 2, 3, 4, 5, 6];
};

const clicBtnMapCoor = () => {
  const url =
    "https://google.com/maps/search/" +
    modelLatitude.value +
    "," +
    modelLongitude.value;
  window.open(url, "_blank");
};

const rulesName = ref([(value) => !!value || "Merci de choisir un nom."]);
const rulesNameClient = ref([
  (value) => !!value || "Merci de choisir un nom de client.",
]);
const rulesLivreur = ref([
  (value) => !!value || "Merci de choisir un livreur.",
]);
const rulesSubscriber = ref([
  (value) => !!value || "Merci de choisir des abonnés.",
]);
const rulesTimeH = ref([
  (value) =>
    (modelCheckWithRepeat.value && value != null) || "Choisissez une heure",
]);
const rulesTimeM = ref([
  (value) =>
    (modelCheckWithRepeat.value && value != null) || "Choisissez des minutes",
]);
const rulesLatitude = ref([(value) => isFloat(value) || "Latitude invalide"]);
const rulesLongitude = ref([(value) => isFloat(value) || "Longitude invalide"]);

const formSubmit = async () => {
  var { valid } = await form.value.validate();
  await Promise.resolve(users.value)
  .then(usersResolved => {
    // Vérifier que usersResolved est bien un tableau
    if (!Array.isArray(usersResolved)) {
      console.error("users.value n'est pas un tableau.");
      return;
    }

    if(usersResolved.length==1)
    modelNameClient.value = usersResolved[0].Username
    // Trouver l'utilisateur par son Username
    if (!modelNameClient.value)
      modelNameClient.value = clientNanme.value 
    const clientNameInput = String(modelNameClient.value);

    const user = usersResolved.find(u =>
      u.Attributes.some(attr =>
        attr.Name === "custom:clientName" && attr.Value === clientNameInput
      ) &&
      u.Attributes.some(attr =>
        attr.Name === "custom:deliveryChecking"
      )
    );
    
    // Trouver l'attribut custom:deliveryChecking
     deliveryCheckingAttr.value = user.Attributes.find(attr => attr.Name === "custom:deliveryChecking");
    //  if (deliveryCheckingAttr.value.Value == true) {
    //   console.log("custom:deliveryChecking:", deliveryCheckingAttr.value);
    // } else {
    //   console.log("L'attribut custom:deliveryChecking n'existe pas pour cet utilisateur.");
    //   deliveryCheckingAttr.value = false
    // }
      });
  
  if (
    modelCheckWithRepeat.value &&
    Object.keys(modelToggleDays.value).length === 0
  ) {
    errorDays.value = true;
    valid = false;
  }
  if (valid) {
    const subscriberIds = modelSubscribers.value.map(
      (subscriber) => subscriber.id
    );
    const daysOfWeek = Array(7)
      .fill(false)
      .map((_, index) => Object.values(modelToggleDays.value).includes(index));
    const startTime = modelHour.value + modelMinute.value / 60;
    const missionInput = {
      owner: clientNanme.value ?? modelNameClient.value,
      name: modelName.value,
      livreurID: modelLivreur.value.id,
      startLatitude: modelLatitude.value,
      startLongitude: modelLongitude.value,
      generateDayBefore: !!modelCheckDayBefore.value,
      daysOfWeek: modelCheckWithRepeat.value ? daysOfWeek : null,
      startTime: modelCheckWithRepeat.value ? startTime : null,
      startTimeZone: modelCheckWithRepeat.value ? modelTimeZone.value : null,
      deliveryChecking: deliveryCheckingAttr.value.Value,
      
    };
    console.log("On est avant l'envoie", missionInput)
    if (selectedStartName.value != null) {
      missionInput.startName = selectedStartName.value;
    }

    try {
      cardLoading.value = true;
      btnLoading.value = true;

      if (missionEdit.value != null && missionEdit.value.id != undefined) {
        missionInput.id = missionEdit.value.id;
        console.log("Envoi ici ")
        const updateMission = await missionUpdate(missionInput);
        await updateMissionSubscribersId({
          missionId: updateMission.id,
          subscriberIds: subscriberIds,
          oldSubscriberIds: missionEdit.value.subscribers.items.map(
            (item) => item.id
          ),
        });
        console.log("Mission mise à jour avec succès : ", updateMission.id);
        router.push("/mission/" + missionEdit.value.id);
      } else {
        const newMission = await missionCreate(missionInput);
        await updateMissionSubscribersId({
          missionId: newMission.id,
          subscriberIds: subscriberIds,
        });
        console.log("Mission créée avec succès : ", newMission.id);
        router.push("/mission/" + newMission.id);
      }
    } catch (error) {
      console.log("ERROR create mission :", error);
      showError(
        "Erreur lors de la création de la mission (" + formatError(error) + ")"
      );
    } finally {
      cardLoading.value = false;
      btnLoading.value = false;
    }
  }
};
const textBtnSubmit = computed(() => {
  return missionEdit.value == null
    ? "Créer la mission"
    : "Mettre à jour la mission";
});
const textTitle = computed(() => {
  return missionEdit.value == null
    ? "CRÉER UNE MISSION"
    : "METTRE À JOUR UNE MISSION";
});
const nbSubscriber = computed(() => {
  const nb = modelSubscribers.value ? modelSubscribers.value.length : 0;
  return nb > 0 ? nb + " Abonné" + (nb > 1 ? "s" : "") : "Abonnés";
});

const clicLoadMoreSubscriber = async () => {
  loadMoreSubLoading.value = true;
  await fetchSubscribers(route.params.id);
  loadMoreSubLoading.value = false;
};
const clearComboSub = async () => {
  autoSelectSub.value = true;
  modelSubscribers.value = [];
};

const selectSubByName = () => {
  if (!autoSelectSub.value) return;
  let name = modelName.value?.toLowerCase().replace(/\./g, "") ?? null;
  if (name == null) return;
  let selectSub = listSubscriber.value.filter(function (subscriber) {
        return subscriber.secteur.toLowerCase().replace(/\./g, "") === name;
  });
  console.log("list Subscribers", listSubscriber.value)
  console.log("select sub : ",selectSub)
  if (selectSub.length > 0) {
    modelSubscribers.value = selectSub;
  }
};
</script>

<template>
  <h1 class="pa-8">{{ textTitle }}</h1>

  <v-card
    :disabled="cardLoading"
    :loading="cardLoading"
    elevation="3"
    class="ma-8 pa-8"
  >
    <v-form ref="form" @submit.prevent="formSubmit">
      <v-row>
        <v-col class="text-form" cols="12">
          <p>Le nom de votre mission :</p>
        </v-col>
        <v-col cols="12" md="6">
          <v-text-field
            label="Nom"
            v-model="modelName"
            :rules="rulesName"
            variant="solo"
            @input="selectSubByName()"
          ></v-text-field>
        </v-col>
      </v-row>

      <v-row v-if="clientNanme == null">
        <v-col class="text-form" cols="12">
          <p>Le nom du client :</p>
        </v-col>
        <v-col cols="12" md="6">
          <v-text-field
            label="Nom client"
            v-model="modelNameClient"
            :rules="rulesNameClient"
            variant="solo"
          ></v-text-field>
        </v-col>
      </v-row>

      <v-row>
        <v-col class="text-form" cols="12">
          <p>Séléctionnez le livreur :</p>
        </v-col>
        <v-col cols="12" md="6">
          <v-combobox
            :loading="userLoading"
            label="Livreur"
            return-object
            v-model="modelLivreur"
            :hint="`${modelLivreur ? modelLivreur.id : ``}`"
            item-props
            :rules="rulesLivreur"
            :items="listLivreur"
            variant="solo"
          ></v-combobox>
        </v-col>
      </v-row>

      <v-row>
        <v-col cols="auto">
          <p>Sélectionnez les abonnés ({{ listSubscriber.length }}) :</p>
        </v-col>
        <v-col cols="auto">
          <v-btn
            v-if="listSubscriberNextToken != null"
            :loading="loadMoreSubLoading"
            prepend-icon="mdi-plus"
            rounded="xl"
            size="small"
            variant="outlined"
            :color="color.primary"
            @click="clicLoadMoreSubscriber"
          >
            Charger plus d'abonnés
          </v-btn>
        </v-col>
      </v-row>
      <v-row class="d-flex align-center">
        <v-col cols="11">
          <v-combobox
            :loading="subscriberLoading"
            :label="nbSubscriber"
            return-object
            v-model="modelSubscribers"
            item-props
            :items="listSubscriber"
            :rules="rulesSubscriber"
            variant="solo"
            multiple
            chips
            closable-chips
            clear-icon="clear"
          ></v-combobox>
        </v-col>
        <v-col cols="1">
          <v-btn class="btn-clear" @click.stop="clearComboSub()" rounded
            ><v-icon :size="20">mdi-close</v-icon></v-btn
          >
        </v-col>
      </v-row>

      <v-row>
        <v-checkbox
          label="Avec récurrence ?"
          class="ml-4 mt-4 checkbox_days"
          v-model="modelCheckWithRepeat"
        ></v-checkbox>
      </v-row>

      <v-row v-if="modelCheckWithRepeat">
        <v-col class="text-form" cols="12">
          <p>Quel jour de la semaine cette mission doit être effectuée :</p>
        </v-col>
        <v-col cols="12" class="d-flex align-center">
          <v-row>
            <v-col cols="auto">
              <v-btn-toggle
                :class="{ error: errorDays }"
                v-model="modelToggleDays"
                rounded="s"
                multiple
                :color="color.primary"
                variant="outlined"
              >
                <v-btn><b>L</b></v-btn>
                <v-btn><b>M</b></v-btn>
                <v-btn><b>M</b></v-btn>
                <v-btn><b>J</b></v-btn>
                <v-btn><b>V</b></v-btn>
                <v-btn><b>S</b></v-btn>
                <v-btn><b>D</b></v-btn>
              </v-btn-toggle>
            </v-col>
            <v-col cols="auto">
              <v-checkbox
                label="Toute la semaine"
                class="ml-4 checkbox_days"
                v-model="modelCheckAllDays"
                @click="onAllDaysChanghe"
              ></v-checkbox>
            </v-col>
          </v-row>
        </v-col>
      </v-row>

      <v-row v-if="modelCheckWithRepeat">
        <v-col class="text-form" cols="12">
          <p>
            À quelle heure
            {{ modelCheckDayBefore ? "la veille," : "de la journée" }} cette
            mission sera disponible :
          </p>
        </v-col>
        <v-col cols="6" sm="3">
          <v-select
            v-model="modelHour"
            :items="hours"
            :rules="rulesTimeH"
            label="Heure"
            variant="solo"
          ></v-select>
        </v-col>
        <v-col cols="6" sm="3">
          <v-select
            v-model="modelMinute"
            :items="minutes"
            :rules="rulesTimeM"
            label="Minute"
            variant="solo"
          ></v-select>
        </v-col>
        <v-col class="text-form" cols="auto">
          <v-checkbox
            label="Heure de la veille ?"
            class="ml-4 checkbox_days"
            v-model="modelCheckDayBefore"
          ></v-checkbox>
        </v-col>
      </v-row>

      <v-row>
        <v-col class="text-form" cols="12">
          <p>Choisissez le point de départ :</p>
        </v-col>
        <v-col cols="6">
          <GoogleAutocomplete
            id="map"
            ref="googleAutocomplete"
            classname="form-control"
            placeholder="Recherchez une adresse"
            @placechanged="getAddressData"
            @inputChange="onAddressChange"
          >
          </GoogleAutocomplete>
        </v-col>
      </v-row>
      <v-row>
        <v-col cols="3">
          <v-text-field
            label="Latitude"
            v-model="modelLatitude"
            :rules="rulesLatitude"
            variant="solo"
          ></v-text-field>
        </v-col>
        <v-col cols="3">
          <v-text-field
            label="Longitude"
            v-model="modelLongitude"
            :rules="rulesLongitude"
            variant="solo"
          ></v-text-field>
        </v-col>
        <v-col>
          <v-btn
            @click="clicBtnMapCoor"
            :disabled="!btnMapCoorEnable"
            icon="mdi-map-search-outline"
          ></v-btn>
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
</template>

<style>
.v-counter {
  display: none !important;
}
.error .v-btn {
  color: rgb(var(--v-theme-error));
}
</style>
<style scoped>
.text-form {
  padding-bottom: 0;
}
p {
  font-size: 1.2em;
  font-weight: 500;
}
.btn-clear {
  min-width: 32px;
  height: 32px !important;
  padding: 0;
}
</style>

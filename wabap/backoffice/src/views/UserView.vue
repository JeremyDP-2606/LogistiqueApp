<script setup>
import { onMounted, onUnmounted, ref, inject } from "vue";
import router from "@/router";
import { GoogleMap, Marker, InfoWindow } from "vue3-google-map";
import { useRoute } from "vue-router";
import { color, MARTINIQUE } from "@/util/const";
import { getTourneeByUser } from "@/api/tourneeService";
import { getMissionsByUser } from "@/api/missionService";
import pin_livreur from "@/assets/pin_livreur.png";
import {
  getAttribute,
  statusColor,
  statusName,
  formatCoordonne,
  formatError,
  formatDateTime,
  formatDuration,
  formatDistance,
  formatLivreurName,
  nbColisByStatus,
} from "@/util/util";
import { getUser, getGroupUser, deleteUser } from "@/api/userService";
import { API, graphqlOperation } from "@aws-amplify/api";
import { listLocations } from "@/graphql/queries";
import {
  onCreateLocation,
  onUpdateLocation,
  onDeleteLocation,
} from "@/graphql/subscriptions";
import { isAdmin } from "@/util/auth";

const route = useRoute();
const showError = inject("showError");
const admin = ref(false);
const loadingUser = ref(false);
const loadingTournees = ref(false);
const loadingMissions = ref(false);
const user = ref(null);
const groupUser = ref(null);
const tournees = ref(null);
const tourneesNextToken = ref(null);
const missions = ref(null);
const listUserLocation = ref([]);

onMounted(async () => {
  admin.value = await isAdmin();
  Promise.all([fetchUser(route.params.id)]).then(() => {
    fetchGroupsUser(user.value.Username);
  });
  fetchTournees(route.params.id);
  fetchMissions(route.params.id);
  await fetchLocation(route.params.id);
  subscribeCreateLocation(route.params.id);
  subscribeUpdateLocation(route.params.id);
  subscribeDeleteLocation(route.params.id);
});

onUnmounted(() => {
  createLocationSubscription?.unsubscribe();
  updateLocationSubscription?.unsubscribe();
  deleteLocationSubscription?.unsubscribe();
});

const fetchUser = async (sub) => {
  try {
    loadingUser.value = true;
    user.value = await getUser(sub);
  } catch (error) {
    console.error(">>> Error : USER", error);
    showError(
      "Erreur de chargement de l'utilisateur (" + formatError(error) + ")"
    );
  }
  loadingUser.value = false;
};

const fetchTournees = async (idUser, nextToken = null) => {
  try {
    loadingTournees.value = color.primary;
    const resultat = await getTourneeByUser(idUser, nextToken);
    if (tournees.value == null) tournees.value = resultat.items;
    else tournees.value = tournees.value.concat(resultat.items);
    tourneesNextToken.value = resultat.nextToken;
  } catch (error) {
    console.error(">>> Error : TOURNEES", error);
    showError("Erreur de chargement des tournées (" + formatError(error) + ")");
  }
  loadingTournees.value = false;
};
const clicLoadMoreTournee = () => {
  fetchTournees(route.params.id, tourneesNextToken.value);
};

const fetchMissions = async (idUser) => {
  try {
    loadingMissions.value = color.primary;
    const resultat = await getMissionsByUser(idUser);
    missions.value = resultat;
  } catch (error) {
    console.error(">>> Error : MISSIONS", error);
    showError("Erreur de chargement des missions (" + formatError(error) + ")");
  }
  loadingMissions.value = false;
};

const fetchGroupsUser = async (username) => {
  try {
    groupUser.value = await getGroupUser(username);
  } catch (error) {
    console.error(">>> Error : GROUPUSER", error);
    showError("Erreur de chargement du rôle (" + formatError(error) + ")");
  }
};

const fetchLocation = async (userId) => {
  const resultat = await API.graphql(
    graphqlOperation(listLocations, {
      filter: {
        userId: {
          eq: userId,
        },
      },
    })
  );
  listUserLocation.value = resultat.data.listLocations.items;
};

let createLocationSubscription;
const subscribeCreateLocation = (userId) => {
  createLocationSubscription = API.graphql(
    graphqlOperation(onCreateLocation, {
      filter: {
        userId: {
          eq: userId,
        },
      },
    })
  ).subscribe({
    next: (locationData) => {
      listUserLocation.value.push(locationData.value.data.onCreateLocation);
    },
    error: (error) =>
      console.error(">>> ERROR : subscribeCreateLocation", error),
  });
};

let updateLocationSubscription;
const subscribeUpdateLocation = (userId) => {
  updateLocationSubscription = API.graphql(
    graphqlOperation(onUpdateLocation, {
      filter: {
        userId: {
          eq: userId,
        },
      },
    })
  ).subscribe({
    next: (locationData) => {
      var updateLocation = locationData.value.data.onUpdateLocation;
      listUserLocation.value = listUserLocation.value.filter(
        (location) => location.id !== updateLocation.id
      );
      listUserLocation.value.push(updateLocation);
    },
    error: (error) =>
      console.error(">>> ERROR : subscribeUpdateLocation", error),
  });
};

let deleteLocationSubscription;
const subscribeDeleteLocation = (userId) => {
  deleteLocationSubscription = API.graphql(
    graphqlOperation(onDeleteLocation, {
      filter: {
        userId: {
          eq: userId,
        },
      },
    })
  ).subscribe({
    next: (locationData) => {
      var deleteLocation = locationData.value.data.onDeleteLocation;
      listUserLocation.value = listUserLocation.value.filter(
        (location) => location.id !== deleteLocation.id
      );
    },
    error: (error) =>
      console.error(">>> ERROR : subscribeDeleteLocation", error),
  });
};

const clicTournee = (id) => {
  router.push("/tournee/" + id);
};
const clicBtnEdit = (id) => {
  router.push("/user/edit/" + id);
};

const loadingRemove = ref(false);
const verifRemove = ref(false);
const dialogRemove = ref(false);
const textFieldDelete = ref(null);
const onConfirmRemoveChange = (username, inputValue) => {
  verifRemove.value = inputValue === username;
};
const clicBtnRemove = async (username) => {
  try {
    dialogRemove.value = false;
    loadingRemove.value = true;
    await deleteUser(username);
    router.push("/users/");
  } catch (error) {
    console.error(">>> Error : REMOVE USER", error);
    showError(
      "Erreur lors de la suppression de l'utilisateur (" +
        formatError(error) +
        ")"
    );
  }
  loadingRemove.value = false;
};
</script>

<template>
  <div class="loader" v-show="user == undefined">
    <v-progress-circular
      :size="50"
      :width="5"
      indeterminate
      color="primary"
    ></v-progress-circular>
  </div>
  <div class="content" v-show="user != undefined">
    <v-row class="pa-8 align-center">
      <v-col cols="auto">
        <h1 class="pa-8">UTILISATEUR : {{ user?.Username }}</h1>
      </v-col>
      <v-col class="text-end">
        <v-btn
          v-if="admin"
          prepend-icon="mdi-pencil-outline"
          rounded="xl"
          size="large"
          type="submit"
          variant="outlined"
          :color="color.primary"
          @click="clicBtnEdit(route.params.id)"
          >Éditer l'utilisateur</v-btn
        >
      </v-col>
    </v-row>

    <v-card elevation="3" class="ma-8 pa-8">
      <v-row>
        <v-col cols="2" class="d-flex align-center">
          <p>Mission{{ missions?.length > 1 ? "s" : "" }} :</p>
        </v-col>
        <v-col>
          <span v-if="missions?.length > 0">
            <v-chip
              class="mr-2"
              v-for="mission in missions"
              v-bind:key="mission.id"
              color="primary"
              link
              @click="clicMission(mission.id)"
              >{{ mission.name }}
              <v-icon :size="20">mdi-chevron-right</v-icon></v-chip
            >
          </span>
          <v-chip v-else color="error">Aucune mission</v-chip>
        </v-col>
      </v-row>
      <v-row>
        <v-col cols="2" class="d-flex align-center">
          <p>Username :</p>
        </v-col>
        <v-col>{{ user?.Username }}</v-col>
      </v-row>
      <v-row>
        <v-col cols="2" class="d-flex align-center">
          <p>Prénom :</p>
        </v-col>
        <v-col>{{ getAttribute(user, "given_name") }}</v-col>
      </v-row>
      <v-row>
        <v-col cols="2" class="d-flex align-center">
          <p>Nom :</p>
        </v-col>
        <v-col>{{ getAttribute(user, "family_name") }}</v-col>
      </v-row>
      <v-row>
        <v-col cols="2" class="d-flex align-center">
          <p>Email :</p>
        </v-col>
        <v-col>{{ getAttribute(user, "email") }}</v-col>
      </v-row>
      <v-row>
        <v-col cols="2" class="d-flex align-center">
          <p>Rôle :</p>
        </v-col>
        <v-col>
          <span v-if="groupUser != null">
            <v-chip
              color="primary"
              v-for="(group, index) in groupUser"
              :key="index"
            >
              {{ group }}
            </v-chip>
          </span>
        </v-col>
      </v-row>
      <v-row v-if="groupUser =='admin'">
        <v-col cols="2" class="d-flex align-center">
          <p>Contrôle de livraison :</p>
        </v-col>
        <v-col>{{ getAttribute(user, "custom:deliveryChecking")=="true" ? "Activé" : "Désactivé"}}</v-col>
      </v-row>
    </v-card>

    <v-card ref="cardMap" elevation="3" class="ma-8 pa-8">
      <GoogleMap
        style="width: 100%; height: 500px"
        :center="MARTINIQUE"
        :zoom="10"
        ref="googleMap"
      >
        <Marker
          v-for="location in listUserLocation"
          v-bind:key="location.id"
          :options="{
            position: {
              lat: location?.latitude ?? 0,
              lng: location?.longitude ?? 0,
            },
            icon: {
              url: pin_livreur,
              scaledSize: { width: 40, height: 40 },
            },
          }"
        >
          <InfoWindow>
            <div>
              <h2>
                <b>{{ location?.userName ?? location?.userId }}</b>
              </h2>
              <p>
                Dernière mise à jour :
                {{ formatDateTime(location?.lastUpdate) }}
              </p>
              <p>latitude : {{ formatCoordonne(location?.latitude) }}</p>
              <p>longitude : {{ formatCoordonne(location?.longitude) }}</p>
            </div>
          </InfoWindow></Marker
        >
      </GoogleMap>
    </v-card>
    <h1 class="px-8">Les tournées :</h1>
    <v-card :loading="loadingTournees" elevation="3" class="ma-8 pa-8">
      <v-table>
        <thead>
          <tr>
            <th>Nom</th>
            <th>Statut</th>
            <th>Livreur</th>
            <th>Durée</th>
            <th>Distance</th>
            <th>Colis</th>
          </tr>
        </thead>
        <tbody>
          <tr
            class="clickable"
            v-for="tournee in tournees"
            :key="tournee.id"
            @click="clicTournee(tournee.id)"
            v-ripple
          >
            <td>
              <b>{{ tournee.name }}</b>
            </td>
            <td>
              <v-chip :color="statusColor(tournee.status)">
                {{ statusName(tournee.status) }}
              </v-chip>
            </td>
            <td>
              <span>
                {{ formatLivreurName(user) }}
              </span>
            </td>
            <td>
              {{ formatDuration(tournee.duree) }}
            </td>
            <td>
              {{ formatDistance(tournee.distance) }}
            </td>
            <td>
              {{ nbColisByStatus(tournee.colis?.items, "COMPLETED") }}/{{
                tournee.colis?.items.length ?? 0
              }}
              <v-tooltip open-delay="500" activator="parent" location="top">
                {{
                  statusName("PENDING") +
                  " : " +
                  nbColisByStatus(tournee.colis?.items, "PENDING")
                }}<br />
                {{
                  statusName("IN_PROGRESS") +
                  " : " +
                  nbColisByStatus(tournee.colis?.items, "IN_PROGRESS")
                }}<br />
                {{
                  statusName("ISSUE") +
                  " : " +
                  nbColisByStatus(tournee.colis?.items, "ISSUE")
                }}<br />
                {{
                  statusName("COMPLETED") +
                  " : " +
                  nbColisByStatus(tournee.colis?.items, "COMPLETED")
                }}
              </v-tooltip>
            </td>
          </tr>
        </tbody>
      </v-table>

      <v-row v-if="tourneesNextToken" class="pt-5">
        <v-col cols="12" class="d-flex justify-center align-center">
          <v-btn
            :loading="listLoading"
            prepend-icon="mdi-arrow-down"
            append-icon="mdi-arrow-down"
            rounded="xl"
            size="small"
            variant="outlined"
            :color="color.primary"
            @click="clicLoadMoreTournee"
            >Charger plus</v-btn
          >
        </v-col>
      </v-row>
    </v-card>

    <v-row class="pa-8 mb-4">
      <v-col class="text-end">
        <v-dialog v-model="dialogRemove" width="500">
          <template v-slot:activator="{ props }">
            <v-btn
              v-if="admin"
              v-bind="props"
              prepend-icon="mdi-trash-can-outline"
              rounded="xl"
              size="large"
              type="submit"
              variant="outlined"
              color="red-accent-4"
              :loading="loadingRemove"
              >Supprimer l'utilisateur</v-btn
            >
          </template>

          <v-card title="Suppression impossible" v-if="missions?.length > 0">
            <v-card-text>
              Il est impossible de supprimer un utilisateur qui est livreur
              d'une mission.
            </v-card-text>
            <v-card-actions>
              <v-spacer />
              <v-btn text="Annuler" @click="dialogRemove = false" />
            </v-card-actions>
          </v-card>

          <v-card title="Confirmez suppression" v-else>
            <v-card-text>
              Etes-vous certain de vouloir supprimer cet utilisateur ?
              <v-col cols="12">
                <v-text-field
                  :label="
                    'Tapez « ' + user.Username + ' » pour pouvoir valider'
                  "
                  @input="
                    onConfirmRemoveChange(user.Username, textFieldDelete.value)
                  "
                  variant="solo"
                  ref="textFieldDelete"
                ></v-text-field>
              </v-col>
            </v-card-text>

            <v-card-actions>
              <v-spacer />

              <v-btn text="Annuler" @click="dialogRemove = false" />
              <v-btn
                text="Valider"
                :disabled="!verifRemove"
                @click="clicBtnRemove(user.Username)"
              />
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-col>
    </v-row>
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
.qrcode {
  cursor: pointer;
}
</style>

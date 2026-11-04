<script setup>
import { ref, onMounted, onUnmounted, inject } from "vue";
import { color, MARTINIQUE } from "@/util/const";
import { getUsers, getGroupUser } from "@/api/userService";
import router from "@/router";
import { GoogleMap, Marker, InfoWindow } from "vue3-google-map";
import { API, graphqlOperation } from "@/api/client";
import { listLocations } from "@/graphql/queries";
import pin_livreur from "@/assets/pin_livreur.png";
import {
  onCreateLocation,
  onUpdateLocation,
  onDeleteLocation,
} from "@/graphql/subscriptions";
import {
  formatLivreurName,
  formatCoordonne,
  getAttribute,
  formatError,
  formatDateTime,
} from "@/util/util";
import { isAdmin, getClientName } from "@/util/auth";

const showError = inject("showError");
const admin = ref(false);
const users = ref([]);
const listLoading = ref(false);
const listLivreurLocation = ref([]);
const clientName = ref(null);

// TODO : refacto GoogleMap
onMounted(async () => {
  admin.value = await isAdmin();
  fetchLivreurs();
  await fetchLocation();
  subscribeCreateLocation();
  subscribeUpdateLocation();
  subscribeDeleteLocation();
  clientName.value = await getClientName();
});

onUnmounted(() => {
  createLocationSubscription?.unsubscribe();
  updateLocationSubscription?.unsubscribe();
  deleteLocationSubscription?.unsubscribe();
});

const fetchLivreurs = async () => {
  try {
    listLoading.value = color.primary;
    users.value = await getUsers();
  } catch (error) {
    showError("Erreur de chargement  (" + formatError(error) + ")");
  }
  listLoading.value = false;
};

const fetchLocation = async () => {
  const resultat = await API.graphql(graphqlOperation(listLocations));
  listLivreurLocation.value = resultat.data.listLocations.items;
};

let createLocationSubscription;
const subscribeCreateLocation = () => {
  createLocationSubscription = API.graphql(
    graphqlOperation(onCreateLocation)
  ).subscribe({
    next: (locationData) => {
      listLivreurLocation.value.push(locationData.value.data.onCreateLocation);
    },
    error: (error) =>
      console.error(">>> ERROR : subscribeCreateLocation", error),
  });
};

let updateLocationSubscription;
const subscribeUpdateLocation = () => {
  updateLocationSubscription = API.graphql(
    graphqlOperation(onUpdateLocation)
  ).subscribe({
    next: (locationData) => {
      var updateLocation = locationData.value.data.onUpdateLocation;
      listLivreurLocation.value = listLivreurLocation.value.filter(
        (location) => location.id !== updateLocation.id
      );
      listLivreurLocation.value.push(updateLocation);
    },
    error: (error) =>
      console.error(">>> ERROR : subscribeUpdateLocation", error),
  });
};

let deleteLocationSubscription;
const subscribeDeleteLocation = () => {
  deleteLocationSubscription = API.graphql(
    graphqlOperation(onDeleteLocation)
  ).subscribe({
    next: (locationData) => {
      var deleteLocation = locationData.value.data.onDeleteLocation;
      listLivreurLocation.value = listLivreurLocation.value.filter(
        (location) => location.id !== deleteLocation.id
      );
    },
    error: (error) =>
      console.error(">>> ERROR : subscribeDeleteLocation", error),
  });
};

const clickUser = async (user) => {
  router.push("/user/" + getAttribute(user, "sub"));
};

const cacheGroupsUser = new Map();
const fetchGroupsUser = (username) => {
  console.log("fetchGroupUser", username);
  if (cacheGroupsUser.has(username)) {
    return cacheGroupsUser.get(username);
  }
  const groups = ref(null);
  cacheGroupsUser.set(username, groups);
  getGroupUser(username)
    .then((data) => {
      groups.value = data;
    })
    .catch((error) => {
      console.error("Error fetchGroupsUser:", error);
      groups.value = [];
    });
  return groups;
};

const clicBtnCreate = () => {
  router.push("/user/create");
};
</script>

<template>
  <v-row class="pa-8 align-center">
    <v-col cols="auto">
      <h1>UTILISATEURS</h1>
    </v-col>
    <v-col class="text-end">
      <v-btn
        v-if="admin"
        prepend-icon="mdi-plus"
        rounded="xl"
        size="large"
        type="submit"
        variant="outlined"
        :color="color.primary"
        @click="clicBtnCreate"
        >Ajouter un utilisateur</v-btn
      >
    </v-col>
  </v-row>
  <v-card :loading="listLoading" elevation="3" class="ma-8 pa-8">
    <v-table>
      <thead>
        <tr>
          <th class="text-left">Username</th>
          <th class="text-left">Nom</th>
          <th class="text-left">Email</th>
          <th class="text-left">Type</th>
          <th v-if="clientName == null" class="text-left">Client</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="user in users"
          :key="user.Username"
          class="clickable"
          @click="clickUser(user)"
        >
          <td>{{ user.Username }}</td>
          <td>{{ formatLivreurName(user, "") }}</td>
          <td>{{ getAttribute(user, "email") }}</td>
          <td>
            <span v-if="fetchGroupsUser(user.Username).value != null">
              <v-chip
                color="primary"
                v-for="(group, index) in fetchGroupsUser(user.Username).value"
                :key="index"
              >
                {{ group }}
              </v-chip>
            </span>
            <v-progress-circular
              v-else
              :size="20"
              :width="2"
              indeterminate
              color="primary"
            ></v-progress-circular>
          </td>
          <td v-if="clientName == null">{{ getAttribute(user, "custom:clientName") }}</td>
        </tr>
      </tbody>
    </v-table>
  </v-card>
  <v-card ref="cardMap" :loading="listLoading" elevation="3" class="ma-8 pa-8">
    <GoogleMap
      style="width: 100%; height: 500px"
      :center="MARTINIQUE"
      :zoom="10"
      ref="googleMap"
    >
      <Marker
        v-for="location in listLivreurLocation"
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
              Dernière mise à jour : {{ formatDateTime(location?.lastUpdate) }}
            </p>
            <p>latitude : {{ formatCoordonne(location?.latitude) }}</p>
            <p>longitude : {{ formatCoordonne(location?.longitude) }}</p>
          </div>
        </InfoWindow></Marker
      >
    </GoogleMap>
  </v-card>
</template>

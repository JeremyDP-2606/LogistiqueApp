<script setup>
import { onMounted, ref, inject } from "vue";
import router from "@/router";
import { GoogleMap, Marker, InfoWindow } from "vue3-google-map";
import { useRoute } from "vue-router";
import { color } from "@/util/const";
import pin from "@/assets/pin.png";
import pin_done from "@/assets/pin_green.png";
import pin_error from "@/assets/pin_error.png";
import pin_progress from "@/assets/pin_progress.png";
import { colisGet, getListColisStatus } from "@/api/colisService";
import {
  statusColor,
  statusName,
  formatCoordonne,
  formatError,
  formatDateTimeTournee,
  formatDateTime,
} from "@/util/util";

const route = useRoute();
const showError = inject("showError");
const cardMap = ref(null);
const googleMap = ref(null);
const colis = ref(null);
const listColisStatus = ref(null);
const listColisStatusWithPosition = ref(null);
const listColisStatusNextToken = ref(null);
const listLoading = ref(false);

onMounted(async () => {
  fetchColis(route.params.id);
  fetchColisStatus(route.params.id);
});

const fetchColis = async (colisId) => {
  try {
    colis.value = await colisGet(colisId);
  } catch (error) {
    showError("Erreur de chargement  (" + formatError(error) + ")");
  }
};

const fetchColisStatus = async (colisId, nextToken = null) => {
  try {
    listLoading.value = color.primary;
    const resultat = await getListColisStatus(colisId, nextToken);
    if (listColisStatus.value == null) listColisStatus.value = resultat.items;
    else listColisStatus.value = listColisStatus.value.concat(resultat.items);
    listColisStatusNextToken.value = resultat.nextToken;
    listColisStatusWithPosition.value = listColisStatus.value.filter(
      (c) => c.latitude && c.longitude
    );
  } catch (error) {
    showError("Erreur de chargement  (" + formatError(error) + ")");
  } finally {
    listLoading.value = false;
  }
};

const clicTournee = (id) => {
  router.push("/tournee/" + id);
};

const clicLoadMoreColisStatus = () => {
  fetchColisStatus(route.params.id, listColisStatusNextToken.value);
};

const clicSubscriber = (id) => {
  router.push("/subscriber/" + id);
};

const clicBtnMapCoor = (lat, lng) => {
  const url = "https://google.com/maps/search/" + lat + "," + lng;
  window.open(url, "_blank");
};

const pinColor = (status) => {
  if (status == "PENDING") return pin;
  if (status == "IN_PROGRESS") return pin_progress;
  if (status == "ISSUE") return pin_error;
  if (status == "COMPLETED") return pin_done;
  return "grey";
};

const clickColisStatus = (colisstatus) => {
  if (colisstatus.latitude == undefined || colisstatus.longitude == undefined) return;
  const position = { lat: colisstatus.latitude, lng: colisstatus.longitude };
  googleMap.value.map.panTo(position);
  googleMap.value.map.setZoom(19);
  cardMap.value.$el.scrollIntoView({
    behavior: "smooth",
  });
};
</script>

<template>
  <div class="loader" v-show="colis == undefined">
    <v-progress-circular
      :size="50"
      :width="5"
      indeterminate
      color="primary"
    ></v-progress-circular>
  </div>
  <div class="content" v-show="colis != undefined">
    <h1 class="pa-8">COLIS : {{ colis?.name }}</h1>

    <v-card elevation="3" class="ma-8 pa-8">
      <v-row>
        <v-col cols="12">
          <v-row>
            <v-col cols="3" sm="2">
              <p>Tournée :</p>
            </v-col>
            <v-col>
              <v-chip
                v-if="colis?.tournee != null"
                color="primary"
                link
                @click="clicTournee(colis?.tournee.id)"
                >{{ colis?.tournee.name }}
                <v-icon :size="20">mdi-chevron-right</v-icon></v-chip
              >
              <v-chip v-else color="error">Aucune tournée</v-chip>
            </v-col>
          </v-row>
          <v-row>
            <v-col cols="3" sm="2">
              <p>Abonnée :</p>
            </v-col>
            <v-col>
              <v-chip
                v-if="colis?.subscriber != null"
                color="primary"
                link
                @click="clicSubscriber(colis?.subscriber.id)"
                >{{ colis?.subscriberName }}
                <v-icon :size="20">mdi-chevron-right</v-icon></v-chip
              >
              <p v-else>{{ colis?.subscriberName }}</p>
            </v-col>
          </v-row>
          <v-row>
            <v-col cols="3" sm="2">
              <p>Status :</p>
            </v-col>
            <v-col>
              <v-chip :color="statusColor(colis?.lastStatus.status)">
                {{ statusName(colis?.lastStatus.status) }}
              </v-chip></v-col
            >
          </v-row>
          <v-row>
            <v-col cols="3" sm="2">
              <p>Adresse :</p>
            </v-col>
            <v-col>{{ colis?.address }}</v-col>
          </v-row>
        </v-col>
      </v-row>
    </v-card>

    <v-card ref="cardMap" elevation="3" class="ma-8 pa-8">
      <GoogleMap
        v-if="colis?.latitude && colis?.longitude"
        style="width: 100%; height: 500px"
        :center="{
          lat: colis?.latitude ?? 0,
          lng: colis?.longitude ?? 0,
        }"
        :zoom="15"
        ref="googleMap"
      >
        <Marker
          :options="{
            position: { lat: colis?.latitude, lng: colis?.longitude },
          }"
        >
          <InfoWindow>
            <div>
              <h3>
                <b>{{ colis?.subscriber?.name ?? "" }}</b>
              </h3>
              <p>{{ colis?.address }}</p>
              <p>latitude : {{ formatCoordonne(colis?.latitude) }}</p>
              <p>longitude : {{ formatCoordonne(colis?.longitude) }}</p>
            </div>
          </InfoWindow></Marker
        >
        <Marker
          v-for="colisStatus in listColisStatusWithPosition"
          v-bind:key="colisStatus.id"
          :options="{
            position: {
              lat: colisStatus?.latitude ?? 0,
              lng: colisStatus?.longitude ?? 0,
            },
            icon: {
              url: pinColor(colisStatus.status),
              scaledSize: { width: 40, height: 40 },
            },
          }"
        >
          <InfoWindow>
            <div>
              <h2>
                <b>{{ statusName(colisStatus.status) }}</b>
              </h2>
              <p>
                Date :
                {{ formatDateTime(colisStatus.createdAt) }}
              </p>
              <p>
                Message :
                {{ colisStatus.message }}
              </p>
              <p>latitude : {{ formatCoordonne(colisStatus?.latitude) }}</p>
              <p>longitude : {{ formatCoordonne(colisStatus?.longitude) }}</p>
            </div>
          </InfoWindow></Marker
        >
      </GoogleMap>
    </v-card>
    <h1 class="px-8">L'historique du colis :</h1>
    <v-card :loading="listLoading" elevation="3" class="ma-8 pa-8">
      <v-table>
        <thead>
          <tr>
            <th class="text-left">Date</th>
            <th class="text-left">Status</th>
            <th class="text-left">Message</th>
            <th class="text-left">GPS</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="colisStatus in listColisStatus" :key="colisStatus.id"
            class="clickable"
            @click="clickColisStatus(colisStatus)">
            <td>
              {{ formatDateTimeTournee(colisStatus.createdAt) }}
            </td>
            <td>
              <v-chip :color="statusColor(colisStatus.status)">
                {{ statusName(colisStatus.status) }}
              </v-chip>
            </td>
            <td>
              {{ colisStatus.message }}
            </td>
            <td>
              <v-btn
                v-if="
                  colisStatus.latitude != null && colisStatus.longitude != null
                "
                class="btn-rond"
                rounded
                @click.stop="
                  clicBtnMapCoor(colisStatus.latitude, colisStatus.longitude)
                "
                ><v-icon :size="15">mdi-map-search-outline</v-icon></v-btn
              >
            </td>
          </tr>
        </tbody>
      </v-table>

      <v-row v-if="listColisStatusNextToken" class="pt-5">
        <v-col cols="12" class="d-flex justify-center align-center">
          <v-btn
            :loading="listLoading"
            prepend-icon="mdi-arrow-down"
            append-icon="mdi-arrow-down"
            rounded="xl"
            size="small"
            variant="outlined"
            :color="color.primary"
            @click="clicLoadMoreColisStatus"
            >Charger plus</v-btn
          >
        </v-col>
      </v-row>
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
.btn-rond {
  min-width: 32px;
  height: 32px !important;
  padding: 0;
}
</style>

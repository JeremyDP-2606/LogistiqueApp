<script setup>
import { onMounted, ref, inject } from "vue";
import { subscriberGet } from "@/api/subscriberService";
import router from "@/router";
import { GoogleMap, Marker, InfoWindow } from "vue3-google-map";
import QrcodeVue from "qrcode.vue";
import { useRoute } from "vue-router";
import { color, MARTINIQUE } from "@/util/const";
import { getColisBySubscriber } from "@/api/colisService";
import {
  formatLivreurName,
  formatDateTournee,
  statusColor,
  statusName,
  formatCoordonne,
  formatError,
  formatDateTime
} from "@/util/util";
import { getUser } from "@/api/userService";

const route = useRoute();
const showError = inject("showError");
const subscriber = ref(null);
const downloadUrl = ref(null);
const qrcode = ref(null);
const listColis = ref(null);
const listColisNextToken = ref(null);
const listLoading = ref(false);

onMounted(async () => {
  fetchSubscriber(route.params.id);
  fetchColis(route.params.id);
});

const fetchSubscriber = async (tourneeId) => {
  try {
    subscriber.value = await subscriberGet(tourneeId);
  } catch (error) {
    showError("Erreur de chargement  (" + formatError(error) + ")");
  }
};

const fetchColis = async (subscriberId, nextToken = null) => {
  try {
    listLoading.value = color.primary;
    const resultat = await getColisBySubscriber(subscriberId, nextToken);
    if (listColis.value == null) listColis.value = resultat.items;
    else listColis.value = listColis.value.concat(resultat.items);
    listColisNextToken.value = resultat.nextToken;
  } catch (error) {
    showError("Erreur de chargement  (" + formatError(error) + ")");
  } finally {
    listLoading.value = false;
  }
};

const prepareDownload = async () => {
  const canvas = qrcode.value.$el;
  downloadUrl.value = canvas.toDataURL("image/png");
};

const clicMission = (id) => {
  router.push("/mission/" + id);
};

const clicTournee = (id) => {
  router.push("/tournee/" + id);
};

const clicLivreur = (id) => {
  router.push("/user/" + id);
};

const clicColis = (id) => {
  router.push("/colis/" + id);
};

const clicLoadMoreSubscriber = () => {
  fetchColis(route.params.id, listColisNextToken.value);
};

const cacheLivreurName = new Map();
const fetchLivreurName = (sub) => {
  console.log("fetchLivreurName", sub);
  if (cacheLivreurName.has(sub)) {
    return cacheLivreurName.get(sub);
  }
  const name = ref(null);
  cacheLivreurName.set(sub, name);
  getUser(sub)
    .then((livreur) => {
      name.value = formatLivreurName(livreur);
    })
    .catch((error) => {
      console.error("Error fetching livreur name:", error);
      name.value = sub.split("-")[0];
    });
  return name;
};
</script>

<template>
  <div class="loader" v-show="subscriber == undefined">
    <v-progress-circular
      :size="50"
      :width="5"
      indeterminate
      color="primary"
    ></v-progress-circular>
  </div>
  <div class="content" v-show="subscriber != undefined">
    <h1 class="pa-8">ABONNÉ : {{ subscriber?.name }}</h1>

    <v-card elevation="3" class="ma-8 pa-8">
      <v-row>
        <v-col cols="12" md="9">
          <v-row>
            <v-col cols="4" sm="3">
              <p>N° abo :</p>
            </v-col>
            <v-col>{{ subscriber?.numabo }}</v-col>
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Mission :</p>
            </v-col>
            <v-col>
              <v-chip
                v-if="subscriber?.mission != null"
                color="primary"
                link
                @click="clicMission(subscriber?.mission.id)"
                >{{ subscriber?.mission.name }}
                <v-icon :size="20">mdi-chevron-right</v-icon></v-chip
              >
              <v-chip v-else color="error">Aucune mission</v-chip>
            </v-col>
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Abonné :</p>
            </v-col>
            <v-col
              ><v-chip
                v-if="subscriber?.unsubscribed != null"
                :color="subscriber?.unsubscribed ? 'error' : 'green'"
                >{{ subscriber?.unsubscribed ? "Désabonné" : "Abonné" }}
              </v-chip></v-col
            >
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Nom :</p>
            </v-col>
            <v-col>{{ subscriber?.name }}</v-col>
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Adresse :</p>
            </v-col>
            <v-col>{{ subscriber?.address }}</v-col>
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Instructions :</p>
            </v-col>
            <v-col>{{ subscriber?.instructions }}</v-col>
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Création :</p>
            </v-col>
            <v-col>{{ formatDateTime(subscriber?.createdAt) }}</v-col>
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Modification :</p>
            </v-col>
            <v-col>{{ formatDateTime(subscriber?.updatedAt) }}</v-col>
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Secteur :</p>
            </v-col>
            <v-col>{{ subscriber?.secteur }}</v-col>
          </v-row>
          <v-row>
            <v-col cols="4" sm="3">
              <p>Téléphone :</p>
            </v-col>
            <v-col>{{ subscriber?.phone1 }}</v-col>
          </v-row>
        </v-col>

        <v-col cols="12" md="3" class="d-flex justify-center align-center">
          <a
            class="qrcode"
            :href="downloadUrl"
            :download="'qrcode-' + subscriber?.numabo + '.png'"
            @click="prepareDownload"
          >
            <qrcode-vue
              ref="qrcode"
              :value="subscriber?.numabo"
              :size="200"
            ></qrcode-vue>
          </a>
        </v-col>
      </v-row>
    </v-card>

    <v-card ref="cardMap" elevation="3" class="ma-8 pa-8">
      <GoogleMap
        style="width: 100%; height: 500px"
        :center="{
          lat: subscriber?.latitude ?? MARTINIQUE.lat,
          lng: subscriber?.longitude ?? MARTINIQUE.lng,
        }"
        :zoom="subscriber?.latitude ? 15 : 10"
        ref="googleMap"
      >
        <Marker
          :options="{
            position: { lat: subscriber?.latitude, lng: subscriber?.longitude },
          }"
        >
          <InfoWindow>
            <div>
              <h3>
                <b>{{ subscriber?.name }}</b>
              </h3>
              <p>{{ subscriber?.address }}</p>
              <p>latitude : {{ formatCoordonne(subscriber?.latitude) }}</p>
              <p>longitude : {{ formatCoordonne(subscriber?.longitude) }}</p>
            </div>
          </InfoWindow></Marker
        >
      </GoogleMap>
    </v-card>
    <h1 class="px-8">Les colis :</h1>
    <v-card :loading="listLoading" elevation="3" class="ma-8 pa-8">
      <v-table>
        <thead>
          <tr>
            <th class="text-left">Date</th>
            <th class="text-left">Tournée</th>
            <th class="text-left">Livreur</th>
            <th class="text-left">Status</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="colis in listColis"
            :key="colis.id"
            class="clickable"
            @click="clicColis(colis.id)"
          >
            <td>
              {{ formatDateTournee(colis.createdAt) }}
            </td>
            <td>
              <v-chip
                color="primary"
                link
                @click.stop="clicTournee(colis.tournee.id)"
                >{{ colis.tournee.name }}
                <v-icon :size="20">mdi-chevron-right</v-icon></v-chip
              >
            </td>
            <td>
              <v-progress-circular
                v-if="!fetchLivreurName(colis.tournee.livreurID).value"
                :size="20"
                :width="2"
                indeterminate
                color="primary"
              ></v-progress-circular>
              <span v-else>
                <v-chip
                  color="primary"
                  link
                  @click.stop="clicLivreur(colis.tournee.id)"
                  >{{ fetchLivreurName(colis.tournee.livreurID).value }}
                  <v-icon :size="20">mdi-chevron-right</v-icon></v-chip
                >
              </span>
            </td>
            <td>
              <v-chip :color="statusColor(colis.lastStatus.status)">
                {{ statusName(colis.lastStatus.status) }}
              </v-chip>
            </td>
          </tr>
        </tbody>
      </v-table>

      <v-row v-if="listColisNextToken" class="pt-5">
        <v-col cols="12" class="d-flex justify-center align-center">
          <v-btn
            :loading="listLoading"
            prepend-icon="mdi-arrow-down"
            append-icon="mdi-arrow-down"
            rounded="xl"
            size="small"
            variant="outlined"
            :color="color.primary"
            @click="clicLoadMoreSubscriber"
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
.qrcode {
  cursor: pointer;
}
</style>

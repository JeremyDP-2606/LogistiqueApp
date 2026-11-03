<script setup>
import { ref, onMounted, inject, computed } from "vue";
import { missionGet, missionDelete } from "@/api/missionService";
import { useRoute } from "vue-router";
import { color } from "@/util/const";
import { formatDuration, formatDistance } from "@/util/util";
import { getUser } from "@/api/userService";
import { getTourneeByMission } from "@/api/tourneeService";
import router from "@/router";
import {
  formatHeure,
  formatLivreurName,
  statusColor,
  statusName,
  nbColisByStatus,
  formatCoordonnes,
  formatError,
} from "@/util/util";
import { createTournee } from "@/api/lambdaService";
import { isAdmin } from "@/util/auth";

const showError = inject("showError");
const admin = ref(false);
const loading = ref(false);
const mission = ref(null);
const loadingLivreur = ref(false);
const livreur = ref(null);
const loadingTournees = ref(false);
const loadingCreateTournees = ref(false);
const tournees = ref(null);
const tourneesNextToken = ref(null);
const route = useRoute();
const loadingRemove = ref(false);
const verifRemove = ref(false);
const dialogRemove = ref(false);
const textFieldDelete = ref(null);

const days = ["L", "M", "M", "J", "V", "S", "D"];

onMounted(async () => {
  admin.value = await isAdmin();
  fetchTournees(route.params.id);
  await fetchMission(route.params.id);
  fetchLivreur(mission.value?.livreurID);
});

const fetchMission = async (id) => {
  try {
    loading.value = true;
    mission.value = await missionGet(id);
    console.log(JSON.stringify(mission.value));
  } catch (error) {
    console.error(">>> Error : MISSIONS", error);
    showError("Erreur de chargement mission (" + formatError(error) + ")");
  }
  loading.value = false;
};

const fetchLivreur = async (sub) => {
  try {
    loadingLivreur.value = true;
    livreur.value = await getUser(sub);
    console.log(JSON.stringify(livreur.value));
  } catch (error) {
    console.error(">>> Error : LIVREUR", error);
    showError("Erreur de chargement livreur (" + formatError(error) + ")");
  }
  loadingLivreur.value = false;
};

const fetchTournees = async (idMission, nextToken = null) => {
  try {
    loadingTournees.value = color.primary;
    const resultat = await getTourneeByMission(idMission, nextToken);
    if (tournees.value == null) tournees.value = resultat.items;
    else tournees.value = tournees.value.concat(resultat.items);
    tourneesNextToken.value = resultat.nextToken;
    console.log(JSON.stringify(tournees.value));
  } catch (error) {
    console.error(">>> Error : TOURNEES", error);
    showError("Erreur de chargement tournées (" + formatError(error) + ")");
  }
  loadingTournees.value = false;
};

const colorDay = (i) =>
  computed(function () {
    return mission.value?.daysOfWeek && mission.value?.daysOfWeek[i] ? "primary" : "second";
  });
const heure = computed(() => {
  return formatHeure(mission.value?.startTime);
});
const clicBtnEdit = () => {
  router.push("/mission/edit/" + mission.value?.id);
};
const clicBtnCreateTournee = async () => {
  try {
    loadingCreateTournees.value = true;
    const rep = await createTournee(mission.value?.id);
    const newTournee = JSON.parse(rep.body);
    tournees.value.unshift(newTournee);
    console.log(">>> NEW TOURNEE", newTournee);
  } catch (error) {
    console.error(">>> Error : CREATE TOURNEES", error);
    showError("Erreur de création de la tournées (" + formatError(error) + ")");
  } finally {
    loadingCreateTournees.value = false;
  }
};
const clicBtnRemove = async (id) => {
  try {
    dialogRemove.value = false;
    loadingRemove.value = true;
    const rep = await missionDelete(id);
    console.log("REMOVE (" + id + ")", rep);
    router.push("/missions/");
  } catch (error) {
    console.error(">>> Error : REMOVE MISSIONS", error);
    showError(
      "Erreur lors de la suppression de la mission (" + formatError(error) + ")"
    );
  }
  loadingRemove.value = false;
};
const clicLoadMoreTournee = () => {
  fetchTournees(route.params.id, tourneesNextToken.value);
};
const clicLivreur = (id) => {
  router.push("/user/" + id);
};
const clicSubscriber = (id) => {
  router.push("/subscriber/" + id);
};
const clicTournee = (id) => {
  router.push("/tournee/" + id);
};
const clicBtnMapCoor = () => {
  const url =
    "https://google.com/maps/search/" +
    mission.value?.startLatitude +
    "," +
    mission.value?.startLongitude;
  window.open(url, "_blank");
};
const livreurName = computed(() => {
  return formatLivreurName(livreur.value);
});

const livreurId = computed(() => {
  return mission.value?.livreurID;
});
const startName = computed(() => {
  return mission.value?.startName && mission.value?.startName != ""
    ? mission.value?.startName
    : formatCoordonnes(
        mission.value?.startLatitude,
        mission.value?.startLongitude
      );
});

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
const onConfirmRemoveChange = (missionName, inputValue) => {
  verifRemove.value = inputValue === missionName;
};
</script>

<template>
  <div class="loader" v-show="loading">
    <v-progress-circular
      :size="50"
      :width="5"
      indeterminate
      color="primary"
    ></v-progress-circular>
  </div>
  <div class="content" v-show="!loading && mission != undefined">
    <v-row class="pa-8">
      <v-col cols="auto">
        <h1>MISSION : {{ mission?.name }}</h1>
        <p class="subtitle">Id : {{ mission?.id }}</p>
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
          @click="clicBtnEdit"
          >Éditer la mission</v-btn
        >
      </v-col>
    </v-row>

    <v-card
      :disabled="cardLoading"
      :loading="cardLoading"
      elevation="3"
      class="ma-8 pa-8"
    >
      <v-row>
        <v-col cols="12" md="3">
          <p>
            <v-icon :size="20">mdi-truck-delivery-outline</v-icon> Le livreur :
          </p>
        </v-col>
        <v-col cols="12" md="9">
          <v-chip
            v-show="!loadingLivreur"
            color="primary"
            link
            @click="clicLivreur(livreurId)"
          >
            <p>
              {{ livreurName }}
              <v-tooltip open-delay="500" activator="parent" location="top">{{
                livreurId
              }}</v-tooltip>
              <v-icon :size="20">mdi-chevron-right</v-icon>
            </p>
          </v-chip>
          <v-progress-circular
            v-show="loadingLivreur"
            :size="20"
            :width="2"
            indeterminate
            color="primary"
          ></v-progress-circular>
        </v-col>
      </v-row>

      <v-row>
        <v-col cols="auto">
          <p class="mb-1">
            <v-icon :size="20">mdi-account-group</v-icon> Les abonnés ({{
              mission?.subscribers.items.length
            }}) :
          </p>
          <v-card class="pa-4">
            <v-chip
              v-for="abonne in mission?.subscribers.items"
              :key="abonne.id"
              color="primary"
              class="ma-2"
              link
              @click="clicSubscriber(abonne.id)"
              >{{ abonne.name
              }}<v-tooltip open-delay="500" activator="parent" location="top">{{
                abonne.id
              }}</v-tooltip></v-chip
            >
          </v-card>
        </v-col>
      </v-row>

      <v-row v-if="mission?.daysOfWeek && mission?.startTime && mission?.startTimeZone">
        <v-col cols="12">
          <p class="mb-1">
            <v-icon :size="20" class="mb-1 mr-2">mdi-clock-outline</v-icon
            >{{ mission?.generateDayBefore == true ? "La veille à " : "À" }}
            {{ heure + " " }}({{ mission?.startTimeZone }})
          </p>
          <div class="d-flex align-center">
            <v-card class="pa-2">
              <v-chip
                v-for="(day, i) in days"
                :key="i"
                :color="colorDay(i).value"
                text-color="white"
                size="x-large"
                class="ma-2"
                >{{ day }}</v-chip
              >
            </v-card>
          </div>
        </v-col>
      </v-row>

      <v-row>
        <v-col cols="6" class="d-flex">
          <v-icon :size="20" class="mt-1 mr-2">mdi-map-marker</v-icon>
          <p>{{ startName }}</p>
        </v-col>
        <v-col cols="6">
          <v-btn @click="clicBtnMapCoor" icon="mdi-map-search-outline"></v-btn>
        </v-col>
      </v-row>
    </v-card>

    <v-row class="pa-8">
      <v-col cols="auto">
        <h1>Les dernières tournées</h1>
      </v-col>
      <v-col class="text-end">
        <v-btn
          v-if="admin"
          :loading="loadingCreateTournees"
          prepend-icon="mdi-plus"
          rounded="xl"
          size="large"
          type="submit"
          variant="outlined"
          :color="color.primary"
          @click="clicBtnCreateTournee"
          >Générer une tournée</v-btn
        >
      </v-col>
    </v-row>

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
              <v-progress-circular
                v-if="!fetchLivreurName(tournee.livreurID).value"
                :size="20"
                :width="2"
                indeterminate
                color="primary"
              ></v-progress-circular>
              <span v-else>
                {{ fetchLivreurName(tournee.livreurID).value }}
                <v-tooltip open-delay="500" activator="parent" location="top">{{
                  tournee.livreurID
                }}</v-tooltip>
              </span>
            </td>
            <td>
              {{ formatDuration(tournee.duree) }}
            </td>
            <td>
              {{ formatDistance(tournee.distance) }}
            </td>
            <td>
              {{ nbColisByStatus(tournee.colis?.items, "COMPLETED")+nbColisByStatus(tournee.colis?.items, "ISSUE") }}/{{
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
            :loading="loadingTournees"
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
              >Supprimer la mission</v-btn
            >
          </template>

          <v-card title="Confirmez suppression">
            <v-card-text>
              Etes-vous certain de vouloir supprimer cette mision ? Cela
              supprimera toutes les tournées associées.
              <v-col cols="12">
                <v-text-field
                  :label="'Tapez « ' + mission.name + ' » pour pouvoir valider'"
                  @input="
                    onConfirmRemoveChange(mission.name, textFieldDelete.value)
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
                @click="clicBtnRemove(mission.id)"
              />
            </v-card-actions>
          </v-card>
        </v-dialog>
      </v-col>
    </v-row>
  </div>
</template>

<style scoped>
.subtitle {
  color: grey;
  font-size: 0.8em;
}

.loader {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100%;
  height: 100%;
}
p {
  font-size: 1.2em;
  font-weight: 500;
}
</style>

<script setup>
import { ref, onMounted, inject } from "vue";
import { color } from "@/util/const";
import { getMissions } from "@/api/missionService";
import { getLastTourneeByMission } from "@/api/tourneeService";
import router from "@/router";
import { getUser } from "@/api/userService";
import {
  formatLivreurName,
  statusColor,
  statusName,
  nbColisByStatus,
  formatError,
} from "@/util/util";
import { isAdmin, getClientName } from "@/util/auth";

const showError = inject("showError");
const admin = ref(false);
const clientName = ref(null);
const missions = ref([]);
const listLoading = ref(false);

onMounted(async () => {
  fetchMissions();
  admin.value = await isAdmin();
  clientName.value = await getClientName();
});

const fetchMissions = async () => {
  try {
    listLoading.value = color.primary;
    missions.value = await getMissions();
  } catch (error) {
    console.error(">>> Error : MISSIONS", error);
    showError("Erreur de chargement  (" + formatError(error) + ")");
  }
  listLoading.value = false;
};

const clicBtnCreate = () => {
  router.push("/missions/create");
};

const clicMission = (missionId) => {
  router.push("/mission/" + missionId);
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

const cacheLastTourneeStatus = new Map();
const fetchLastTourneeStatus = (missionId) => {
  console.log("fetchLastTourneeStatus", missionId);
  if (cacheLastTourneeStatus.has(missionId)) {
    return cacheLastTourneeStatus.get(missionId);
  }
  const tournee = ref(null);
  cacheLastTourneeStatus.set(missionId, tournee);
  getLastTourneeByMission(missionId)
    .then((lastTournee) => {
      tournee.value = lastTournee ?? "Auncune tournée";
    })
    .catch((error) => {
      console.error("Error fetching last tournee status:", error);
      tournee.value = "Erreur";
    });
  return tournee;
};
</script>

<template>
  <v-row class="pa-8 align-center">
    <v-col cols="auto">
      <h1>MISSIONS</h1>
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
        >Créer une mission</v-btn
      >
    </v-col>
  </v-row>
  <v-card :loading="listLoading" elevation="3" class="ma-8 pa-8">
    <v-table>
      <thead>
        <tr>
          <th class="text-left">Name</th>
          <th class="text-left">Livreur</th>
          <th class="text-left">Abonnés</th>
          <th class="text-left">Dernière tournée</th>
          <th class="text-left">Postulé</th>
          <th v-if="clientName == null" class="text-left">Client</th>
        </tr>
      </thead>
      <tbody>
        <tr
          class="clickable"
          v-for="mission in missions"
          :key="mission.name"
          @click="clicMission(mission.id)"
          v-ripple
        >
          <td>{{ mission.name }}</td>
          <td>
            <v-progress-circular
              v-if="!fetchLivreurName(mission.livreurID).value"
              :size="20"
              :width="2"
              indeterminate
              color="primary"
            ></v-progress-circular>
            <span v-else>
              {{ fetchLivreurName(mission.livreurID).value }}
              <v-tooltip open-delay="500" activator="parent" location="top">{{
                mission.livreurID
              }}</v-tooltip>
            </span>
          </td>
          <td>
            {{
              (mission.subscribers.nextToken != undefined ? "+" : "") +
              mission.subscribers.items.length
            }}
          </td>
          <td>
            <v-progress-circular
              v-if="!fetchLastTourneeStatus(mission.id).value"
              :size="20"
              :width="2"
              indeterminate
              color="primary"
            ></v-progress-circular>
            <p
              v-else-if="
                typeof fetchLastTourneeStatus(mission.id).value === 'string'
              "
            >
              {{ fetchLastTourneeStatus(mission.id).value }}
            </p>
            <span v-else>
              <b
                >{{ fetchLastTourneeStatus(mission.id).value.name }}
                :
              </b>
              <v-chip
                :color="
                  statusColor(fetchLastTourneeStatus(mission.id).value.status)
                "
              >
                {{
                  statusName(fetchLastTourneeStatus(mission.id).value.status)
                }}
              </v-chip>
              ({{
                nbColisByStatus(
                  fetchLastTourneeStatus(mission.id).value.colis?.items,
                  "COMPLETED"
                ) +
                nbColisByStatus(
                  fetchLastTourneeStatus(mission.id).value.colis?.items,
                  "ISSUE"
                )
              }}/{{
                fetchLastTourneeStatus(mission.id).value.colis?.items.length ??
                0
              }})
            </span>
          </td>
          <td>
            {{
              (mission.inscriptions.nextToken != undefined ? "+" : "") +
              mission.inscriptions.items.length
            }}
          </td>
          <td v-if="clientName == null">{{ mission.owner }}</td>
        </tr>
      </tbody>
    </v-table>
  </v-card>
</template>

<style>
.clickable {
  cursor: pointer;
}
</style>

<script setup>
import { ref, onMounted, inject, computed } from "vue";
import {
  fetchTournees,
  fetchSubscribers,
  fetchLivreurs,
  computeCompletedDeliveries,
  computePendingDeliveries,
  computeSubscribersDelivered,
  computePackagesDelivered
} from "@/api/statisticsService";
import { getMissions } from "@/api/missionService";
import { getTourneeByMission } from "@/api/tourneeService";
import { getTourneeByUser } from "@/api/tourneeService";

const showError = inject("showError");
const subscribers = ref([]);
const missions = ref([]);
const resultMissions = ref({'nbTourneesCompleted' : 0, 'nbTourneesPending' : 0});
const tournees = ref([]);
const listSubscriberNextToken = ref(null);
const livreurs = ref([]);
const carouselIndex = ref(0);
const tourneesByUser = ref({});
const colisDelivered = ref(0);
const nbDeliveriesCompleted = ref(0);
const nbDeliveriesPending = ref(0);
const nbSubscribersDelivered = ref(0);
const nbPackagesDelivered = ref(0);
const isLoading = ref(true);  // Ajout d'un état pour gérer le chargement

onMounted(async () => {
  try {
    // Démarrage du chargement
    isLoading.value = true;

    // Récupération parallèle des livreurs et des missions
    const [livreursData, missionsData] = await Promise.all([fetchLivreurs(), getMissions()]);
    livreurs.value = livreursData;
    missions.value = missionsData;

    tourneesByUser.value = {}; // Réinitialisation propre
    const currentMonth = new Date().toISOString().slice(0, 7);

    // Appels parallèles pour obtenir les tournées des livreurs
    const tourneePromises = livreurs.value.map(livreur => getTourneeByUser(livreur.sub, null, 35));

    const tourneeResults = await Promise.all(tourneePromises);
    
    const tourneesByUserCount = {};
    const colisStatsByUser = {};

    tourneeResults.forEach((tourneeData, index) => {
      const livreur = livreurs.value[index];
      if (!tourneeData || !tourneeData.items) return;

      const tourneesDuMois = tourneeData.items.filter(t => t.createdAt.startsWith(currentMonth));

      let nbColisPending = 0;
      let nbColisCompleted = 0;

      tourneesDuMois.forEach(tournee => {
        if (!tournee.colis || !tournee.colis.items) return;

        tournee.colis.items.forEach(colis => {
          if (colis.lastStatus?.status === "PENDING") nbColisPending++;
          if (colis.lastStatus?.status === "COMPLETED") {
            nbColisCompleted++;
            colisDelivered.value++;
          }
        });
      });

      tourneesByUserCount[livreur.sub] = tourneesDuMois.length;
      colisStatsByUser[livreur.sub] = { nbColisPending, nbColisCompleted };
    });

    // Mise à jour des livreurs avec les nouvelles statistiques
    livreurs.value = livreurs.value.map(livreur => ({
      ...livreur,
      nbTournees: tourneesByUserCount[livreur.sub] || 0,
      nbColisPending: colisStatsByUser[livreur.sub]?.nbColisPending || 0,
      nbColisCompleted: colisStatsByUser[livreur.sub]?.nbColisCompleted || 0
    }));

    // Récupérer d'autres statistiques
    tournees.value = await fetchTournees();
    const subscriberData = await fetchSubscribers();
    subscribers.value = subscriberData.subscribers;
    listSubscriberNextToken.value = subscriberData.nextToken;

    nbDeliveriesCompleted.value = computeCompletedDeliveries(tournees.value);
    nbDeliveriesPending.value = computePendingDeliveries(tournees.value);
    nbSubscribersDelivered.value = computeSubscribersDelivered(tournees.value);
    nbPackagesDelivered.value = computePackagesDelivered(tournees.value);

    // Mise à jour des missions
    resultMissions.value = await fetchMissions();

    // Fin du chargement
    isLoading.value = false;
  } catch (error) {
    showError(error.message);
    isLoading.value = false;  // Fin du chargement même en cas d'erreur
  }
});

const livreurChunks = computed(() => {
  const chunks = [];
  for (let i = 0; i < livreurs.value.length; i += 3) {
    chunks.push(livreurs.value.slice(i, i + 3));
  }
  return chunks;
});

const prev = () => {
  if (carouselIndex.value > 0) {
    carouselIndex.value--;
  }
};

const next = () => {
  if (carouselIndex.value < livreurChunks.value.length - 1) {
    carouselIndex.value++;
  }
};

const fetchMissions = async () => {
  try {
    // Récupérer les missions
    missions.value = await getMissions();

    // Initialiser les variables pour les statistiques
    let nbTourneesPending = 0;
    let nbTourneesCompleted = 0;

    // Récupérer la date du mois en cours
    const currentDate = new Date();
    const currentMonth = currentDate.getMonth(); // Mois courant (0 = janvier, 11 = décembre)
    const currentYear = currentDate.getFullYear(); // Année courante

    // Créer un tableau de promesses pour récupérer les tournées des missions en parallèle
    const tourneePromises = missions.value.map(async (mission) => {
      try {
        const tourneeData = await getTourneeByMission(mission.id, null);

        if (tourneeData && tourneeData.items) {
          // Filtrer les tournées du mois en cours
          const tourneesDuMois = tourneeData.items.filter(tournee => {
            const tourneeDate = new Date(tournee.createdAt);
            return tourneeDate.getMonth() === currentMonth && tourneeDate.getFullYear() === currentYear;
          });

          // Compter les tournées en fonction de leur statut
          tourneesDuMois.forEach(tournee => {
            if (tournee.status === "COMPLETED") {
              nbTourneesCompleted++;
            } else if (tournee.status === "PENDING") {
              nbTourneesPending++;
            }
          });
        }
      } catch (error) {
        console.error(`Erreur lors de la récupération des tournées pour la mission ${mission.id} :`, error);
      }
    });

    // Attendre la résolution de toutes les promesses
    await Promise.allSettled(tourneePromises);

    // Retourner les résultats
    return {
      nbTourneesPending,
      nbTourneesCompleted
    };

  } catch (error) {
    console.error(">>> Error : MISSIONS", error);
  }
};


</script>

<template>
  <v-container>
    <v-row class="pa-8 align-center">
      <v-col cols="auto">
        <h1 class="title">STATISTIQUES MENSUELLES</h1>
      </v-col>
    </v-row>
    
    <!-- Affichage d'un indicateur de chargement -->
    <v-container class="loading-container" v-if="isLoading">
    <v-progress-circular
      indeterminate
      color="primary"
      class="ma-auto align-center"
      size="100"
    ></v-progress-circular>
  </v-container>  

    <!-- Affichage des statistiques si les données sont disponibles -->
    <v-card v-if="!isLoading" elevation="3" class="ma-8 pa-8 stat-card">
      <v-row class="stat-row">
        <v-col cols="3" class="d-flex align-center">
          <p class="stat-title">Livraisons accomplies :</p>
        </v-col>
        <v-col>
          <p class="stat-value">{{ resultMissions.nbTourneesCompleted }}</p>
        </v-col>
      </v-row>
      <v-row class="stat-row">
        <v-col cols="3" class="d-flex align-center">
          <p class="stat-title">Livraisons en attente :</p>
        </v-col>
        <v-col>
          <p class="stat-value">{{ resultMissions.nbTourneesPending }}</p>
        </v-col>
      </v-row>
      <v-row class="stat-row">
        <v-col cols="3" class="d-flex align-center">
          <p class="stat-title">Abonnés livrés :</p>
        </v-col>
        <v-col>
          <p class="stat-value">{{ nbSubscribersDelivered }}</p>
        </v-col>
      </v-row>
      <v-row class="stat-row">
        <v-col cols="3" class="d-flex align-center">
          <p class="stat-title">Colis livrés :</p>
        </v-col>
        <v-col>
          <p class="stat-value">{{ colisDelivered }}</p>
        </v-col>
      </v-row>
    </v-card>

    <v-row class="pa-8 align-center">
      <v-col cols="auto">
        <h1 class="title">LIVREURS</h1>
      </v-col>
    </v-row>

    <div class="carousel-container">
      <v-btn icon @click="prev" class="carousel-button left">
        <v-icon>mdi-chevron-left</v-icon>
      </v-btn>
      <v-window v-model="carouselIndex" class="carousel-window">
        <v-window-item v-for="(chunk, index) in livreurChunks" :key="index">
          <v-row>
            <v-col v-for="livreur in chunk" :key="livreur.sub" cols="4">
              <v-card elevation="3" class="ma-4 pa-4 livreur-card">
                <v-card-title class="livreur-title">{{ livreur.Username }}</v-card-title>
                <v-card-text>
                  <p class="livreur-stat">Tournées assurées : {{ livreur.nbTournees }}</p>
                  <p class="livreur-stat">Colis livrés : {{ livreur.nbColisCompleted }}</p>
                  <p class="livreur-stat">Colis en attente : {{ livreur.nbColisPending }}</p>
                </v-card-text>
              </v-card>
            </v-col>
          </v-row>
        </v-window-item>
      </v-window>
      <v-btn icon @click="next" class="carousel-button right">
        <v-icon>mdi-chevron-right</v-icon>
      </v-btn>
    </div>
  </v-container>
</template>

<style scoped>
/* Ajout d'un style pour le bouton de chargement, et autres ajustements UX */
.carousel-container {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.carousel-window {
  width: 100%;
  max-width: 900px;
}

.carousel-button {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  background-color: rgba(255, 255, 255, 0.9);
  border-radius: 50%;
  z-index: 10;
  padding: 4px;
}

.carousel-button.left {
  left: 10px;
}

.carousel-button.right {
  right: 10px;
}

.stat-card {
  background-color: #f9f9f9;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.stat-row {
  padding: 8px 0;
  font-size: 1.2rem;
}

.stat-title {
  font-weight: bold;
  color: #333;
}

.stat-value {
  font-size: 1.5rem;
  color: #555;
}

.livreur-card {
  background-color: #f9f9f9;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  height: 200px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.livreur-title {
  font-weight: bold;
  color: #333;
}

.livreur-stat {
  font-size: 1rem;
  color: #555;
}

.title {
  font-size: 2rem;
  color: #333;
}
.loading-container {
  display: flex;
  justify-content: center; /* Centre horizontalement */
  align-items: center; /* Centre verticalement */
  height: 10vh; /* Prend toute la hauteur de la fenêtre */
}
</style>

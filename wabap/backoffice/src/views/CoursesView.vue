<script setup>
import { ref, computed, onMounted, inject } from "vue";
import router from "@/router";
import { color } from "@/util/const";
import { formatError } from "@/util/util";
import { listCourses, COURSE_STATUS, VEHICLES, eur, dateTime } from "@/api/courseService";

const showError = inject("showError");
const courses = ref([]);
const loading = ref(false);
const tab = ref("active");
const search = ref("");

const ACTIVE = ["PENDING", "ASSIGNED", "PICKING_UP", "PICKED_UP", "DELIVERING"];

const load = async () => {
  loading.value = color.primary;
  try {
    courses.value = await listCourses();
  } catch (error) {
    showError("Erreur de chargement des courses (" + formatError(error) + ")");
  }
  loading.value = false;
};
onMounted(load);

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  return courses.value.filter((c) => {
    if (tab.value === "active" && !ACTIVE.includes(c.status)) return false;
    if (tab.value === "issue" && c.status !== "ISSUE") return false;
    if (tab.value === "done" && !["COMPLETED", "CANCELLED"].includes(c.status)) return false;
    if (!q) return true;
    return [c.ref, c.clientName, c.courierName, c.owner, c.pickup.address, c.dropoff.address]
      .filter(Boolean)
      .some((v) => v.toLowerCase().includes(q));
  });
});

const stats = computed(() => {
  const done = courses.value.filter((c) => c.status === "COMPLETED");
  return {
    active: courses.value.filter((c) => ACTIVE.includes(c.status)).length,
    issue: courses.value.filter((c) => c.status === "ISSUE").length,
    done: done.length,
    revenue: done.reduce((s, c) => s + c.priceTtc, 0),
  };
});
</script>

<template>
  <v-row class="pa-8 align-center">
    <v-col cols="auto"><h1>COURSES À LA DEMANDE</h1></v-col>
    <v-col class="text-end">
      <v-btn prepend-icon="mdi-refresh" rounded="xl" variant="outlined" :color="color.primary" @click="load">Actualiser</v-btn>
    </v-col>
  </v-row>

  <v-row class="px-8">
    <v-col cols="12" sm="6" md="3"><v-card elevation="2" class="pa-4"><div class="text-caption">En cours</div><div class="text-h5">{{ stats.active }}</div></v-card></v-col>
    <v-col cols="12" sm="6" md="3"><v-card elevation="2" class="pa-4"><div class="text-caption">Problèmes à traiter</div><div class="text-h5" :class="{ 'text-red': stats.issue }">{{ stats.issue }}</div></v-card></v-col>
    <v-col cols="12" sm="6" md="3"><v-card elevation="2" class="pa-4"><div class="text-caption">Livrées</div><div class="text-h5">{{ stats.done }}</div></v-card></v-col>
    <v-col cols="12" sm="6" md="3"><v-card elevation="2" class="pa-4"><div class="text-caption">Chiffre d'affaires TTC</div><div class="text-h5">{{ eur(stats.revenue) }}</div></v-card></v-col>
  </v-row>

  <v-card :loading="loading" elevation="3" class="ma-8 pa-8">
    <v-row class="align-center">
      <v-col cols="12" md="7">
        <v-tabs v-model="tab" :color="color.primary">
          <v-tab value="active">En cours</v-tab>
          <v-tab value="issue">Problèmes</v-tab>
          <v-tab value="done">Terminées</v-tab>
          <v-tab value="all">Toutes</v-tab>
        </v-tabs>
      </v-col>
      <v-col cols="12" md="5">
        <v-text-field v-model="search" density="compact" variant="outlined" prepend-inner-icon="mdi-magnify"
          label="Référence, client, livreur, adresse" hide-details clearable></v-text-field>
      </v-col>
    </v-row>
    <v-table>
      <thead>
        <tr>
          <th>Référence</th><th>Créée le</th><th>Client</th><th>Trajet</th><th>Véhicule</th><th>Livreur</th><th>Prix TTC</th><th>Statut</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="!loading && filtered.length === 0"><td colspan="8" class="text-center text-grey pa-6">Aucune course</td></tr>
        <tr v-for="c in filtered" :key="c.id" class="clickable" v-ripple @click="router.push('/course/' + c.id)">
          <td><b>{{ c.ref }}</b></td>
          <td>{{ dateTime(c.createdAt) }}</td>
          <td>{{ c.clientName ?? "—" }}<div v-if="c.owner" class="text-caption">{{ c.owner }}</div></td>
          <td class="text-caption">{{ c.pickup.address }}<br />→ {{ c.dropoff.address }}</td>
          <td>{{ VEHICLES[c.vehicle] }}</td>
          <td>{{ c.courierName ?? "—" }}</td>
          <td>{{ eur(c.priceTtc) }}</td>
          <td><v-chip size="small" :color="COURSE_STATUS[c.status]?.color">{{ COURSE_STATUS[c.status]?.label ?? c.status }}</v-chip></td>
        </tr>
      </tbody>
    </v-table>
  </v-card>
</template>

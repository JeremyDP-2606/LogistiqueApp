<script setup>
import { ref, computed, onMounted, inject } from "vue";
import { useRoute } from "vue-router";
import { GoogleMap, Marker } from "vue3-google-map";
import { color } from "@/util/const";
import { formatError } from "@/util/util";
import { isAdmin } from "@/util/auth";
import { getCourse, cancelCourse, COURSE_STATUS, VEHICLES, PAYMENT_STATUS, eur, dateTime } from "@/api/courseService";

const showError = inject("showError");
const route = useRoute();
const course = ref(null);
const loading = ref(false);
const admin = ref(false);
const cancelDialog = ref(false);
const cancelReason = ref("");
const cancelling = ref(false);

const CANCELLABLE = ["AWAITING_PAYMENT", "PENDING", "ASSIGNED", "PICKING_UP", "PICKED_UP", "DELIVERING", "ISSUE"];

const load = async () => {
  loading.value = color.primary;
  try {
    course.value = await getCourse(route.params.id);
    if (!course.value) showError("Course introuvable");
  } catch (error) {
    showError("Erreur de chargement (" + formatError(error) + ")");
  }
  loading.value = false;
};

onMounted(async () => {
  admin.value = await isAdmin();
  load();
});

const center = computed(() => {
  const c = course.value;
  return c ? { lat: (c.pickup.latitude + c.dropoff.latitude) / 2, lng: (c.pickup.longitude + c.dropoff.longitude) / 2 } : null;
});

const confirmCancel = async () => {
  cancelling.value = true;
  try {
    const updated = await cancelCourse(course.value.id, cancelReason.value || "Annulée par Wabap");
    cancelDialog.value = false;
    await load();
    if (updated.paymentStatus === "cancelled") showError("Course annulée : l'autorisation de paiement du client est libérée");
  } catch (error) {
    showError("Annulation impossible (" + formatError(error) + ")");
  }
  cancelling.value = false;
};

const stop = (s) => [s.contactName, s.phone, s.instructions].filter(Boolean).join(" · ");
</script>

<template>
  <div v-if="course">
    <v-row class="pa-8 align-center">
      <v-col cols="auto">
        <h1>COURSE {{ course.ref }}</h1>
        <v-chip :color="COURSE_STATUS[course.status]?.color">{{ COURSE_STATUS[course.status]?.label ?? course.status }}</v-chip>
      </v-col>
      <v-col class="text-end">
        <v-btn v-if="admin && CANCELLABLE.includes(course.status)" prepend-icon="mdi-close" rounded="xl" variant="outlined"
          color="red" @click="cancelDialog = true">Annuler la course</v-btn>
      </v-col>
    </v-row>

    <v-row class="px-8">
      <v-col cols="12" md="7">
        <v-card elevation="3" class="pa-6 mb-6">
          <h3 class="mb-2">Trajet</h3>
          <p><b>Retrait</b> — {{ course.pickup.address }}</p>
          <p class="text-caption mb-3">{{ stop(course.pickup) }}</p>
          <p><b>Livraison</b> — {{ course.dropoff.address }}</p>
          <p class="text-caption">{{ stop(course.dropoff) }}</p>
        </v-card>
        <v-card elevation="3" class="pa-2">
          <GoogleMap v-if="center" style="width: 100%; height: 380px" :center="center" :zoom="13">
            <Marker :options="{ position: { lat: course.pickup.latitude, lng: course.pickup.longitude }, label: 'A' }" />
            <Marker :options="{ position: { lat: course.dropoff.latitude, lng: course.dropoff.longitude }, label: 'B' }" />
          </GoogleMap>
        </v-card>
      </v-col>
      <v-col cols="12" md="5">
        <v-card elevation="3" class="pa-6 mb-6">
          <h3 class="mb-2">Détails</h3>
          <v-table density="compact">
            <tbody>
              <tr><td>Créée le</td><td>{{ dateTime(course.createdAt) }}</td></tr>
              <tr><td>Client</td><td>{{ course.clientName ?? course.clientId }}<span v-if="course.owner"> ({{ course.owner }})</span></td></tr>
              <tr><td>Livreur</td><td>{{ course.courierName ?? "—" }}<span v-if="course.courierPhone"> · {{ course.courierPhone }}</span></td></tr>
              <tr><td>Véhicule</td><td>{{ VEHICLES[course.vehicle] }}</td></tr>
              <tr><td>Colis</td><td>{{ course.packageSize }}<span v-if="course.packageDescription"> — {{ course.packageDescription }}</span></td></tr>
              <tr><td>Délai</td><td>{{ course.urgency === "EXPRESS" ? "Express" : "Standard" }}</td></tr>
              <tr><td>Distance</td><td>{{ course.distanceKm }} km</td></tr>
              <tr><td>Prix</td><td>{{ eur(course.priceTtc) }} TTC ({{ eur(course.priceHt) }} HT)</td></tr>
              <tr><td>Rémunération livreur</td><td>{{ eur(course.courierEarning) }}</td></tr>
              <tr><td>Paiement</td><td>{{ PAYMENT_STATUS[course.paymentStatus] ?? course.paymentStatus }}
                <div v-if="course.paymentIntentId" class="text-caption">Stripe : {{ course.paymentIntentId }}</div></td></tr>
              <tr v-if="course.reason"><td>Motif</td><td>{{ course.reason }}</td></tr>
              <tr v-if="course.ratingStars"><td>Note</td><td>{{ "★".repeat(course.ratingStars) }} {{ course.ratingComment }}</td></tr>
            </tbody>
          </v-table>
        </v-card>
        <v-card elevation="3" class="pa-6">
          <h3 class="mb-2">Historique</h3>
          <v-timeline density="compact" side="end">
            <v-timeline-item v-for="e in course.events.items" :key="e.id" size="x-small" :dot-color="COURSE_STATUS[e.status]?.color">
              <b>{{ COURSE_STATUS[e.status]?.label ?? e.status }}</b>
              <div class="text-caption">{{ dateTime(e.createdAt) }}<span v-if="e.message"> — {{ e.message }}</span></div>
            </v-timeline-item>
          </v-timeline>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="cancelDialog" max-width="480">
      <v-card class="pa-4">
        <v-card-title>Annuler la course {{ course.ref }} ?</v-card-title>
        <v-card-text>
          <p v-if="course.paymentMode === 'CARD'" class="mb-4">L'autorisation de paiement du client sera libérée : il ne sera pas débité.</p>
          <v-text-field v-model="cancelReason" label="Motif (visible par le client)" variant="outlined"></v-text-field>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn @click="cancelDialog = false">Retour</v-btn>
          <v-btn color="red" :loading="cancelling" @click="confirmCancel">Annuler la course</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
  <v-progress-linear v-else-if="loading" indeterminate :color="color.primary"></v-progress-linear>
</template>

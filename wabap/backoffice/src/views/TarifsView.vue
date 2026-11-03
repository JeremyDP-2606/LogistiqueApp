<script setup>
import { ref, computed, onMounted, inject } from "vue";
import { color } from "@/util/const";
import { formatError } from "@/util/util";
import { listTarifs, saveTarif, DEFAULT_TARIF, VEHICLES } from "@/api/courseService";

const showError = inject("showError");
const tarifs = ref([]);
const selectedId = ref("default");
const draft = ref(null);
const loading = ref(false);
const saving = ref(false);
const newOrg = ref("");
const SIZES = ["S", "M", "L", "XL"];

const clone = (t) => JSON.parse(JSON.stringify(t));
const exists = computed(() => tarifs.value.some((t) => t.id === selectedId.value));

const load = async () => {
  loading.value = color.primary;
  try {
    tarifs.value = await listTarifs();
    select(selectedId.value);
  } catch (error) {
    showError("Erreur de chargement des tarifs (" + formatError(error) + ")");
  }
  loading.value = false;
};
onMounted(load);

const select = (id) => {
  selectedId.value = id;
  const t = tarifs.value.find((x) => x.id === id);
  draft.value = clone(t ?? { ...DEFAULT_TARIF, id });
};

const addOrg = () => {
  const id = newOrg.value.trim();
  if (!id) return;
  newOrg.value = "";
  select(id);
};

// Exemple de prix pour vérifier la grille avant enregistrement
const example = (v, distanceKm) => {
  const ht = (Number(v.base) + Number(v.perKm) * distanceKm);
  return (ht * (1 + Number(draft.value.vatRate))).toFixed(2).replace(".", ",") + " €";
};

const save = async () => {
  saving.value = true;
  try {
    await saveTarif(draft.value, exists.value);
    await load();
    showError("Grille « " + draft.value.id + " » enregistrée : elle s'applique aux prochains devis");
  } catch (error) {
    showError("Enregistrement impossible (" + formatError(error) + ")");
  }
  saving.value = false;
};
</script>

<template>
  <v-row class="pa-8 align-center">
    <v-col cols="auto"><h1>TARIFS DES COURSES</h1></v-col>
  </v-row>
  <v-row class="px-8">
    <v-col cols="12" md="3">
      <v-card :loading="loading" elevation="3" class="pa-4">
        <v-list density="compact" nav>
          <v-list-subheader>Grilles</v-list-subheader>
          <v-list-item :active="selectedId === 'default'" @click="select('default')" title="Par défaut (particuliers)" />
          <v-list-item v-for="t in tarifs.filter((x) => x.id !== 'default')" :key="t.id" :active="selectedId === t.id"
            @click="select(t.id)" :title="t.id" :subtitle="t.invoice ? 'Facturation mensuelle' : 'Paiement par carte'" />
        </v-list>
        <v-text-field v-model="newOrg" density="compact" variant="outlined" label="Client professionnel" class="mt-4"
          hint="Nom exact de l'organisation (attribut custom:clientName)" persistent-hint></v-text-field>
        <v-btn block class="mt-2" variant="outlined" :color="color.primary" prepend-icon="mdi-plus" @click="addOrg">Ajouter une grille</v-btn>
      </v-card>
    </v-col>
    <v-col cols="12" md="9">
      <v-card v-if="draft" elevation="3" class="pa-6">
        <h3 class="mb-1">{{ draft.id === "default" ? "Grille par défaut" : draft.id }}</h3>
        <p v-if="!exists" class="text-caption mb-4">Nouvelle grille : elle n'est pas encore enregistrée.</p>
        <v-table density="compact">
          <thead>
            <tr><th>Véhicule</th><th>Prise en charge (€ HT)</th><th>Prix au km (€ HT)</th><th>Distance max (km)</th><th>Colis max</th><th>Exemple 5 km TTC</th></tr>
          </thead>
          <tbody>
            <tr v-for="v in draft.vehicles" :key="v.vehicle">
              <td><b>{{ VEHICLES[v.vehicle] }}</b></td>
              <td><v-text-field v-model.number="v.base" type="number" step="0.1" density="compact" hide-details variant="underlined" /></td>
              <td><v-text-field v-model.number="v.perKm" type="number" step="0.05" density="compact" hide-details variant="underlined" /></td>
              <td><v-text-field v-model.number="v.maxKm" type="number" density="compact" hide-details variant="underlined" /></td>
              <td><v-select v-model="v.maxSize" :items="SIZES" density="compact" hide-details variant="underlined" /></td>
              <td>{{ example(v, 5) }}</td>
            </tr>
          </tbody>
        </v-table>
        <v-row class="mt-4">
          <v-col cols="12" sm="4"><v-text-field v-model.number="draft.expressMultiplier" type="number" step="0.05" label="Coefficient express" variant="outlined" hint="1,4 = +40 %" persistent-hint /></v-col>
          <v-col cols="12" sm="4"><v-text-field v-model.number="draft.vatRate" type="number" step="0.005" label="Taux de TVA" variant="outlined" hint="0,085 en Martinique et Guadeloupe, 0,2 en métropole" persistent-hint /></v-col>
          <v-col cols="12" sm="4"><v-text-field v-model.number="draft.courierShare" type="number" step="0.05" label="Part du livreur (sur le HT)" variant="outlined" hint="0,8 = 80 %" persistent-hint /></v-col>
        </v-row>
        <v-switch v-if="draft.id !== 'default'" v-model="draft.invoice" :color="color.primary"
          label="Facturer ce client au mois (pas de paiement par carte)" />
        <div class="text-end mt-4">
          <v-btn :color="color.primary" rounded="xl" size="large" :loading="saving" prepend-icon="mdi-content-save" @click="save">Enregistrer la grille</v-btn>
        </div>
      </v-card>
    </v-col>
  </v-row>
</template>

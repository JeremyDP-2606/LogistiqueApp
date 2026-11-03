<script setup>
import { ref, onMounted, inject, computed } from "vue";
import { color } from "@/util/const";
import { formatError } from "@/util/util";
import { getSubscribers } from "@/api/subscriberService";
import router from "@/router";
import { importCSV, importExcel } from "@/api/lambdaService";
import { isAdmin, getClientName } from "@/util/auth";

const showError = inject("showError");
const admin = ref(false);
const clientName = ref("");
const selectedClient = ref(null);  // Client sélectionné par l'utilisateur
const selectedNumber = ref(3);
const showNumberDialog = ref(false);
const subscribers = ref([]);
const listLoading = ref(false);
const uploadLoading = ref(false);
const listSubscriberNextToken = ref(null);
const fileInput = ref(null);
var clients = ["France-Antilles", "francaise des jeux"];  // Liste des clients disponibles


// Dialog pour sélectionner le client
const showClientDialog = ref(false);

onMounted(async () => {
  fetchSubscribers();
  admin.value = await isAdmin();
  clientName.value = await getClientName();
  if(clientName.value == undefined)
  {
    clientName.value="Admin"
  }
  else
  clients=[clientName.value]


  console.log("clientName", clientName.value)
  console.log("Clients : ", clients)


});

const reFetchSubscribers = async () => {
  subscribers.value = [];
  listSubscriberNextToken.value = null;
  fetchSubscribers();
};

const fetchSubscribers = async () => {
  try {
    listLoading.value = color.primary;
    const resultat = await getSubscribers(listSubscriberNextToken.value);
    if (subscribers.value == null) subscribers.value = resultat.items;
    else subscribers.value = subscribers.value.concat(resultat.items);
    listSubscriberNextToken.value = resultat.nextToken;
  } catch (error) {
    showError("Erreur de chargement  (" + formatError(error) + ")");
  } finally {
    listLoading.value = false;
  }
};

const clickSubscriber = async (id) => {
  router.push("/subscriber/" + id);
};

const clicMission = (id) => {
  router.push("/mission/" + id);
};

const clicLoadMoreSubscribers = () => {
  fetchSubscribers();
};

const clicUploadFile = async () => {
  // Ouvre le dialog pour sélectionner un client
  showClientDialog.value = true;
};

const confirmClientSelection = () => {
  if (!selectedClient.value) {
    showError("Veuillez sélectionner un client avant de continuer.");
    return;
  }
  clientName.value = selectedClient.value;  // Mettre à jour clientName
  if (selectedClient.value == "francaise des jeux"){
    selectedNumber.value = 6;
  }
  showClientDialog.value = false;  // Fermer le dialog
  showNumberDialog.value = true;
};

const confirmNumberSelection = () => {
  showNumberDialog.value = false;
  fileInput.value.click(); // now go to file input
};

const handleFileUpload = async (event) => {
  const file = event.target.files[0];
  if (file) {
    uploadLoading.value = true;
    try {
      const fileName = file.name.toLowerCase();

      if (clientName.value === "France-Antilles") {
        const fichier = await readFile(file);
        await importCSV({ data: fichier, clientName: clientName.value });
      }

      if (clientName.value === "francaise des jeux") {
        const isCSV = fileName.endsWith(".txt");
        if (isCSV) {
          const fichier = await readFile(file);
          await importCSV({ data: fichier, clientName: clientName.value });
        } else {
          const fichier = await readExcelFile(file);
          await importExcel({ data: fichier, clientName: clientName.value, nbColisDefaut: selectedNumber.value });
        }
      }

    } catch (error) {
      showError("Erreur lors du chargement du fichier (" + formatError(error) + ")");
      console.log(error);
    } finally {
      uploadLoading.value = false;
      reFetchSubscribers();
    }
  }
};


const readFile = (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (event) => resolve(event.target.result);
    reader.onerror = (error) => reject(error);
    reader.readAsText(file);
  });
};
const readExcelFile = (file) => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const base64File = reader.result.split(',')[1]; // Extraire la partie base64 (enlever la préfixe 'data:*/*;base64,')
      resolve(base64File);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
};

const clicGps = (lat, lng) => {
  const url = "https://google.com/maps/search/" + lat + "," + lng;
  window.open(url, "_blank");
};

// Stats des abonnés
const nbSubscribeAll = computed(() => {
  return subscribers.value?.length ?? 0;
});
const nbSubscribe = computed(() => {
  return subscribers.value?.filter((s) => !s.unsubscribed).length ?? 0;
});
const nbUnsubscribe = computed(() => {
  return subscribers.value?.filter((s) => s.unsubscribed).length ?? 0;
});
const nbSubscriberWithoutMission = computed(() => {
  return subscribers.value?.filter((s) => !s.unsubscribed && s.mission == null).length ?? 0;
});
const nbSubscriberWithMission = computed(() => {
  return subscribers.value?.filter((s) => s.mission != null).length ?? 0;
});
const nbSubscriberWithoutAdress = computed(() => {
  return subscribers.value?.filter((s) => s.mission != null && (!s.latitude || !s.longitude)).length ?? 0;
});
</script>
<template>
  <v-row class="pa-8 align-center">
    <v-col cols="auto">
      <h1>ABONNÉS</h1>
    </v-col>
    <v-col class="text-end">
      <!-- Bouton pour importer un fichier -->
      <v-btn
        v-if="admin"
        :loading="uploadLoading"
        prepend-icon="mdi-plus"
        rounded="xl"
        size="large"
        type="submit"
        variant="outlined"
        :color="color.primary"
        @click="clicUploadFile"
      >
        Importer fichier
      </v-btn>
      
      <input
        type="file"
        ref="fileInput"
        @change="handleFileUpload"
        accept=".csv, .xlsx"
        style="display: none"
      />
    </v-col>
  </v-row>


  <v-dialog v-model="showNumberDialog" max-width="400px">
    <v-card>
      <v-card-title class="headline">Entrer un nombre de colis par client</v-card-title>
      <v-card-text>
        <v-text-field
          v-model.number="selectedNumber"
          type="number"
          label="Nombre"
          min="1"
          outlined
          dense
        ></v-text-field>
      </v-card-text>
      <v-card-actions>
        <v-btn color="primary" @click="confirmNumberSelection">Confirmer</v-btn>
        <v-btn text @click="showNumberDialog = false">Annuler</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  
  <!-- Dialog pour sélectionner un client -->
  <v-dialog v-model="showClientDialog" max-width="400px">
    <v-card>
      <v-card-title class="headline">Sélectionner un client</v-card-title>
      <v-card-text>
        <v-select
          v-model="selectedClient"
          :items="clients"
          label="Sélectionner un client"
          outlined
          dense
        ></v-select>
      </v-card-text>
      <v-card-actions>
        <v-btn color="primary" @click="confirmClientSelection">Confirmer</v-btn>
        <v-btn text @click="showClientDialog = false">Annuler</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <!-- Contenu de la page avec les abonnés et autres informations -->
  <v-card elevation="3" class="ma-8 pa-8">
    <v-row>
      <v-col cols="3" class="d-flex align-center">
        <p>Nombre abonné :</p>
      </v-col>
      <v-col cols="1" class="d-flex align-center">
        {{ nbSubscribe +"/"+ nbSubscribeAll }} 
      </v-col>
      <v-col cols="3" class="d-flex align-center" v-if="listSubscriberNextToken" >
        <v-btn
          :loading="listLoading"
          rounded="xl"
          size="small"
          variant="outlined"
          :color="color.primary"
          @click="clicLoadMoreSubscribers"
        >
          Charger plus
        </v-btn>
      </v-col>
    </v-row>
    <v-row>
      <v-col cols="3" class="d-flex align-center">
        <p>Nombre désabonné :</p>
      </v-col>
      <v-col>
        {{ nbUnsubscribe +"/"+ nbSubscribeAll }}
      </v-col>
    </v-row>
    <v-row>
      <v-col cols="3" class="d-flex align-center">
        <p>Nombre abonnés et sans mission :</p>
      </v-col>
      <v-col>
        {{ nbSubscriberWithoutMission +"/"+ nbSubscribe }}
      </v-col>
    </v-row>
    <v-row>
      <v-col cols="3" class="d-flex align-center">
        <p>Nombre abonnés avec mission et sans adresse :</p>
      </v-col>
      <v-col>
        {{ nbSubscriberWithoutAdress +"/"+ nbSubscriberWithMission }}
      </v-col>
    </v-row>
  </v-card>

  <v-card :loading="listLoading" elevation="3" class="ma-8 pa-8">
    <v-table>
      <thead>
        <tr>
          <th class="text-left">Abonné</th>
          <th class="text-left">Secteur</th>
          <th class="text-left">Nom</th>
          <th class="text-left">N° abo</th>
          <th class="text-left">Mission</th>
          <th class="text-left">GPS</th>
          <th class="text-left">Client</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="subscriber in subscribers"
          :key="subscriber.name"
          class="clickable"
          @click="clickSubscriber(subscriber.id)"
        >
          <td>
            <v-chip :color="subscriber.unsubscribed ? 'error' : 'green'">
              {{ subscriber.unsubscribed ? "Désabonné" : "Abonné" }}
            </v-chip>
          </td>
          <td>{{ subscriber.secteur }}</td>
          <td>{{ subscriber.name }}</td>
          <td>{{ subscriber.numabo }}</td>
          <td v-if="subscriber.mission != null">
            <v-chip
              color="primary"
              link
              @click.stop="clicMission(subscriber.mission.id)"
            >
              {{ subscriber.mission.name }}
            </v-chip>
          </td>
          <td v-else>
            <v-chip color="error">
              Aucune
            </v-chip>
          </td>
          <td>
            <v-chip
              @click.stop="clicGps(subscriber.latitude, subscriber.longitude)"
              v-if="subscriber.latitude && subscriber.longitude"
              color="green"
            >
              <u>OK</u>
            </v-chip>
            <v-chip v-else color="error">
              KO
            </v-chip>
          </td>
          <td >{{ subscriber.owner }}</td>
        </tr>
      </tbody>
    </v-table>
  </v-card>
</template>

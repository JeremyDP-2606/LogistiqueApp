<script setup>
import { ref, onMounted, onUnmounted, inject, computed } from "vue";
import { color, MARTINIQUE } from "@/util/const";
import {
  formatDuration,
  formatDistance,
  formatLivreurName,
  statusColor,
  statusName,
  formatCoordonne,
  getAttribute,
  formatError,
  formatDateTime,
} from "@/util/util";
import { getColisByTournee } from "@/api/colisService";
import { tourneeGet, tourneeDelete, tourneeUpdate } from "@/api/tourneeService";
import { getUser } from "@/api/userService";
import { useRoute } from "vue-router";
import router from "@/router";
import { GoogleMap, Marker, Polyline, InfoWindow } from "vue3-google-map";
import { decode } from "@googlemaps/polyline-codec";
import pin from "@/assets/pin.png";
import pin_done from "@/assets/pin_green.png";
import pin_error from "@/assets/pin_error.png";
import pin_progress from "@/assets/pin_progress.png";
import pin_livreur from "@/assets/pin_livreur.png";
import { getUsers } from "@/api/userService";
import QrcodeVue from "qrcode.vue";
import { API, graphqlOperation } from "@aws-amplify/api";
import {
  onCreateLocation,
  onUpdateLocation,
  onDeleteLocation,
} from "@/graphql/subscriptions";
import { listLocations } from "@/graphql/queries";
import { isAdmin } from "@/util/auth";
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib';
import QRCode from "qrcode";

const route = useRoute();
const admin = ref(false);
const showError = inject("showError");
const cardMap = ref(null);
const googleMap = ref(null);
const tournee = ref(null);
const listColis = ref(null);
const listColisNextToken = ref(null);
const listLoading = ref(false);
const loadingLivreur = ref(false);
const livreur = ref(null);
const loadingRemove = ref(false);
const verifRemove = ref(false);
const dialogRemove = ref(false);
const showEditLivreur = ref(false);
const userLoading = ref(false);
const listLivreur = ref([]);
const modelLivreur = ref(null);
const listLivreurLocation = ref([]);
const loadingStatus = ref(false);
const labelsLoading = ref(false);
const showEditStatus = ref(false);
const modelStatus = ref(null);
const listStatus = ref([
  { id: "PENDING", title: statusName("PENDING") },
  { id: "IN_PROGRESS", title: statusName("IN_PROGRESS") },
  { id: "ISSUE", title: statusName("ISSUE") },
  { id: "COMPLETED", title: statusName("COMPLETED") },
]);

onMounted(async () => {
  admin.value = await isAdmin();
  fetchColis(route.params.id);
  await fetchTournee(route.params.id);
  fetchLivreur(tournee.value.livreurID);
  await fetchLocation(route.params.id);
  subscribeCreateLocation(route.params.id);
  subscribeUpdateLocation(route.params.id);
  subscribeDeleteLocation(route.params.id);
});

onUnmounted(() => {
  createLocationSubscription?.unsubscribe();
  updateLocationSubscription?.unsubscribe();
  deleteLocationSubscription?.unsubscribe();
});

const fetchTournee = async (tourneeId) => {
  try {
    tournee.value = await tourneeGet(tourneeId);
  } catch (error) {
    showError("Erreur de chargement  (" + formatError(error) + ")");
  }
};

const   fetchColis = async (tourneeId, nextToken = null) => {
  try {
    listLoading.value = color.primary;
    const resultat = await getColisByTournee(tourneeId, nextToken);
    if (listColis.value == null) listColis.value = resultat.items;
    else listColis.value = listColis.value.concat(resultat.items);
    listColisNextToken.value = resultat.nextToken;
  } catch (error) {
    showError("Erreur de chargement  (" + formatError(error) + ")");
  } finally {
    listLoading.value = false;
  }
};

const fetchLivreur = async (sub) => {
  try {
    loadingLivreur.value = true;
    livreur.value = await getUser(sub);
  } catch (error) {
    console.error(">>> Error : LIVREUR", error);
    showError("Erreur de chargement livreur (" + formatError(error) + ")");
  }
  loadingLivreur.value = false;
};

const fetchLocation = async (tourneeId) => {
  const resultat = await API.graphql(
    graphqlOperation(listLocations, {
      filter: {
        tourneeId: {
          eq: tourneeId,
        },
      },
    })
  );
  listLivreurLocation.value = resultat.data.listLocations.items;
};

let createLocationSubscription;
const subscribeCreateLocation = (tourneeId) => {
  createLocationSubscription = API.graphql(
    graphqlOperation(onCreateLocation, {
      filter: {
        tourneeId: {
          eq: tourneeId,
        },
      },
    })
  ).subscribe({
    next: (locationData) => {
      listLivreurLocation.value.push(locationData.value.data.onCreateLocation);
    },
    error: (error) =>
      console.error(">>> ERROR : subscribeCreateLocation", error),
  });
};

let updateLocationSubscription;
const subscribeUpdateLocation = (tourneeId) => {
  updateLocationSubscription = API.graphql(
    graphqlOperation(onUpdateLocation, {
      filter: {
        tourneeId: {
          eq: tourneeId,
        },
      },
    })
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
const subscribeDeleteLocation = (tourneeId) => {
  deleteLocationSubscription = API.graphql(
    graphqlOperation(onDeleteLocation, {
      filter: {
        tourneeId: {
          eq: tourneeId,
        },
      },
    })
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

const fetchLivreurs = async () => {
  try {
    userLoading.value = color.primary;
    const users = await getUsers();
    const list = users.map((user) => ({
      id: getAttribute(user, "sub"),
      title: user.Username,
      subtitle: getAttribute(user, "email"),
    }));
    listLivreur.value = list;
  } catch (error) {
    showError("Erreur de chargement (" + formatError(error) + ")");
  } finally {
    userLoading.value = false;
  }
};

const clickColis = async (id) => {
  router.push("/colis/" + id);
};

const formatPath = (path) => {
  return path.map(([lat, lng]) => ({ lat, lng }));
};

const livreurName = computed(() => {
  return formatLivreurName(livreur.value);
});
const livreurId = computed(() => {
  return tournee.value?.livreurID;
});
const clicLivreur = (id) => {
  router.push("/user/" + id);
};
const clicMission = (id) => {
  router.push("/mission/" + id);
};
const clicSubscriber = (id) => {
  router.push("/subscriber/" + id);
};

const clickNumColis = (colis) => {
  const position = { lat: colis.latitude, lng: colis.longitude };
  googleMap.value.map.panTo(position);
  googleMap.value.map.setZoom(17);
  cardMap.value.$el.scrollIntoView({
    behavior: "smooth",
  });
};

const clicBtnRemove = async (tourneeId, missionId) => {
  try {
    dialogRemove.value = false;
    loadingRemove.value = true;
    const rep = await tourneeDelete(tourneeId);
    console.log("REMOVE (" + tourneeId + ")", rep);
    router.push("/mission/" + missionId);
  } catch (error) {
    console.error(">>> Error : REMOVE TOURNEE", error);
    showError(
      "Erreur lors de la suppression de la tournée (" + formatError(error) + ")"
    );
  }
  loadingRemove.value = false;
};

const clicEditLivreur = () => {
  showEditLivreur.value = true;
  fetchLivreurs();
};
const clicEditStatus = () => {
  showEditStatus.value = true;
};

const clicValidateLivreur = async () => {
  loadingLivreur.value = true;
  tournee.value = await tourneeUpdate({
    id: tournee.value.id,
    livreurID: modelLivreur.value.id,
    status: "PENDING",
  });
  await fetchLivreur(tournee.value.livreurID);
  showEditLivreur.value = false;
  loadingLivreur.value = false;
};

const clicValidateStatus = async () => {
  loadingStatus.value = true;
  tournee.value = await tourneeUpdate({
    id: tournee.value.id,
    status: modelStatus.value.id,
  });
  await fetchLivreur(tournee.value.livreurID);
  showEditStatus.value = false;
  loadingStatus.value = false;
};

const onConfirmRemoveChange = (event) => {
  verifRemove.value = event.target.value === "oui";
};

const clicLoadMoreColis = () => {
  fetchColis(route.params.id, listColisNextToken.value);
};

const pinColor = (status) => {
  if (status == "PENDING") return pin;
  if (status == "IN_PROGRESS") return pin_progress;
  if (status == "ISSUE") return pin_error;
  if (status == "COMPLETED") return pin_done;
  return "grey";
};

/* DEVIS 2 TRACE COLIS */
const generatePDFLabels = async () => {
  labelsLoading.value = true;
  try {
    // Charger tous les colis restants avant de générer les étiquettes
    while (listColisNextToken.value) {
      const token = listColisNextToken.value;
      await fetchColis(route.params.id, token);
      if (listColisNextToken.value === token) return; // échec du chargement (erreur déjà affichée)
    }
    await buildPDFLabels();
  } finally {
    labelsLoading.value = false;
  }
};

const buildPDFLabels = async () => {
  if (!listColis.value || listColis.value.length === 0) {
    console.warn("Aucun colis à imprimer.");
    return;
  }
  console.log("Nb colis : " + listColis.value.length);

  // Create a new PDF document with custom page size (100mm x 140mm)
  const pdfDoc = await PDFDocument.create();
  
  // Convert mm to points (1mm = 2.83465 points)
  const pageWidth = 100 * 2.83465;
  const pageHeight = 140 * 2.83465;
  
  // Load fonts
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  
  // Function to sanitize text for PDF
  const sanitizeText = (text) => {
    if (!text) return 'N/A';
    return text
      .replace(/[\r\n]+/g, ' ') // Replace line breaks with spaces
      .replace(/[\u0000-\u001F\u007F-\u009F]/g, '') // Remove control characters
      .replace(/_/g, ' ') // Replace underscores with spaces
      .trim();
  };

  // Function to format phone numbers
  const formatPhone = (phone) => {
    if (!phone) return 'N/A';
    return phone.replace(/(\d{3,4})(\d{3})(\d{3})/, '$1 $2 $3');
  };

  // Function to draw text with line wrapping
  const drawTextWithWrapping = (text, x, y, maxWidth, fontSize, font) => {
    const sanitizedText = sanitizeText(text);
    const words = sanitizedText.split(' ');
    let line = '';
    let lines = [];
    
    for (let i = 0; i < words.length; i++) {
      const testLine = line + words[i] + ' ';
      const testWidth = font.widthOfTextAtSize(testLine, fontSize);
      
      if (testWidth > maxWidth && i > 0) {
        lines.push(line.trim());
        line = words[i] + ' ';
      } else {
        line = testLine;
      }
    }
    lines.push(line.trim());
    
    return lines;
  };

  for (let i = 0; i < listColis.value.length; i++) {
    const colis = listColis.value[i];
    
    // Create a new page for each label (100mm x 140mm)
    const currentPage = pdfDoc.addPage([pageWidth, pageHeight]);
    
    // Generate QR code
    const qrDataUrl = await QRCode.toDataURL(colis.id, { width: 200 });
    const qrImageBytes = await fetch(qrDataUrl).then(res => res.arrayBuffer());
    const qrImage = await pdfDoc.embedPng(qrImageBytes);
    
    // Calculate positions (all values in points)
    const margin = 10 * 2.83465; // 10mm margin
    const contentWidth = pageWidth - (2 * margin);
    const labelWidth = 40 * 2.83465; // Largeur fixe pour les libellés
    let yOffset = pageHeight - margin - (10 * 2.83465); // Start 10mm from top
    
    // Add text content with appropriate sizing
    const fontSize = 8;
    const lineHeight = 10;
    
    // Destinataire
    currentPage.setFont(boldFont);
    currentPage.setFontSize(fontSize);
    currentPage.drawText('Destinataire :', { x: margin, y: yOffset, color: rgb(0, 0, 0) });
    currentPage.setFont(font);
    
    const subscriberName = sanitizeText(colis.subscriberName).replace(/_/g, ' ');
    const subscriberLines = drawTextWithWrapping(subscriberName, margin + labelWidth, yOffset, contentWidth - labelWidth, fontSize, font);
    subscriberLines.forEach((line, index) => {
      currentPage.drawText(line, { x: margin + labelWidth, y: yOffset - (index * lineHeight), color: rgb(0, 0, 0) });
    });
    yOffset -= (subscriberLines.length * lineHeight + 5);
    
    // Adresse
    currentPage.setFont(boldFont);
    currentPage.drawText('Adresse :', { x: margin, y: yOffset, color: rgb(0, 0, 0) });
    currentPage.setFont(font);
    
    const addressLines = drawTextWithWrapping(colis.address, margin + labelWidth, yOffset, contentWidth - labelWidth, fontSize, font);
    addressLines.forEach((line, index) => {
      currentPage.drawText(line, { x: margin + labelWidth, y: yOffset - (index * lineHeight), color: rgb(0, 0, 0) });
    });
    yOffset -= (addressLines.length * lineHeight + 5);
    
    // Téléphone
    currentPage.setFont(boldFont);
    currentPage.drawText('Téléphone :', { x: margin, y: yOffset, color: rgb(0, 0, 0) });
    currentPage.setFont(font);
    
    const phoneNumbers = formatPhone(colis.subscriber?.phone1);
    const phoneLines = drawTextWithWrapping(phoneNumbers, margin + labelWidth, yOffset, contentWidth - labelWidth, fontSize, font);
    phoneLines.forEach((line, index) => {
      currentPage.drawText(line, { x: margin + labelWidth, y: yOffset - (index * lineHeight), color: rgb(0, 0, 0) });
    });
    yOffset -= (phoneLines.length * lineHeight + 5);
    
    // Commentaire
    currentPage.setFont(boldFont);
    currentPage.drawText('Commentaire :', { x: margin, y: yOffset, color: rgb(0, 0, 0) });
    currentPage.setFont(font);
    
    const instructions = colis.subscriber?.instructions;
    const comment = instructions === 'N/A' || !instructions ? 'Aucun commentaire' : sanitizeText(instructions);
    const commentLines = drawTextWithWrapping(comment, margin + labelWidth, yOffset, contentWidth - labelWidth, fontSize, font);
    commentLines.forEach((line, index) => {
      currentPage.drawText(line, { x: margin + labelWidth, y: yOffset - (index * lineHeight), color: rgb(0, 0, 0) });
    });
    yOffset -= (commentLines.length * lineHeight + 5);
    
    // Code Tournée
    currentPage.setFont(boldFont);
    currentPage.drawText('Code Tournée :', { x: margin, y: yOffset, color: rgb(0, 0, 0) });
    currentPage.setFont(font);
    
    const tourneeName = sanitizeText(tournee.value?.mission?.name).replace(/guymercredinaire/g, '');
    currentPage.drawText(tourneeName, { 
      x: margin + labelWidth, 
      y: yOffset, 
      color: rgb(0, 0, 0),
      maxWidth: contentWidth - labelWidth
    });
    yOffset -= lineHeight;
    
    // Add QR code - Centré horizontalement et positionné en bas
    const qrSize = 50 * 2.83465; // 50mm square
    const qrX = (pageWidth - qrSize) / 2; // Centrage horizontal
    const qrY = margin; // Position en bas (10mm du bord inférieur)
    
    currentPage.drawImage(qrImage, {
      x: qrX,
      y: qrY,
      width: qrSize,
      height: qrSize,
    });
  }
  
  // Save the PDF
  const pdfBytes = await pdfDoc.save();
  const blob = new Blob([pdfBytes], { type: 'application/pdf' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = 'etiquettes_colis.pdf';
  link.click();
  URL.revokeObjectURL(url);
};
</script>

<template>
  <div class="loader" v-show="tournee == undefined">
    <v-progress-circular
      :size="50"
      :width="5"
      indeterminate
    ></v-progress-circular>
  </div>
  <div v-if="tournee" class="tournee-container">
    <v-card v-if="!loading && !cardLoading" class="tournee-card">
      <!-- NEW DEVIS 2-->
      <div class="d-flex align-center gap-4">
        <h1 class="pa-8">TOURNÉE : {{ tournee?.name }}</h1>
        <!-- Bouton pour valider les abonnés -->
        <v-btn
            prepend-icon="mdi-check"
            rounded="xl"
            size="large"
            type="button"
            variant="outlined"
            color="orange"
            :loading="labelsLoading"
            @click="generatePDFLabels"
          >
            Télécharger les étiquettes
          </v-btn>
      </div>
      <!-- END NEW DEVIS 2-->
      

      <v-card elevation="3" class="ma-8 pa-8">
        <v-row>
          <v-col cols="6" md="2" class="d-flex align-center">
            <p>Mission :</p>
          </v-col>
          <v-col cols="6" md="4" class="d-flex align-center">
            <v-chip
              v-show="tournee != null"
              color="primary"
              link
              @click="clicMission(tournee?.mission.id)"
              >{{ tournee?.mission.name }}
              <v-icon :size="20">mdi-chevron-right</v-icon></v-chip
            >
            <v-progress-circular
              v-show="tournee == null"
              :size="20"
              :width="2"
              indeterminate
              color="primary"
            ></v-progress-circular>
          </v-col>
          <v-col cols="6" md="2" class="d-flex align-center">
            <p>Statut :</p>
          </v-col>
          <v-col cols="6" md="4">
            <span v-show="!loadingStatus && !showEditStatus">
              <v-chip :color="statusColor(tournee?.status)">
                {{ statusName(tournee?.status) }}
              </v-chip>
              <v-btn
                v-if="admin"
                class="ml-5 btn-rond pa-0"
                @click.stop="clicEditStatus()"
                rounded
                ><v-icon :size="20">mdi-square-edit-outline</v-icon></v-btn
              ></span
            >
            <span v-show="!loadingStatus && showEditStatus">
              <v-row no-gutters>
                <v-col>
                  <v-combobox
                    class="hide-hint"
                    label="Status"
                    return-object
                    v-model="modelStatus"
                    item-props
                    dense
                    :items="listStatus"
                    style="width: auto"
                    variant="solo"
                  ></v-combobox>
                </v-col>
                <v-col class="d-flex align-center">
                  <v-btn
                    :disabled="modelStatus?.id == undefined"
                    class="ml-5 btn-rond pa-0"
                    @click.stop="clicValidateStatus()"
                    rounded
                    ><v-icon :size="15">mdi-check-bold</v-icon></v-btn
                  >
                </v-col>
              </v-row>
            </span>
            <v-progress-circular
              v-show="loadingStatus"
              :size="20"
              :width="2"
              indeterminate
              color="primary"
            ></v-progress-circular>
          </v-col>
        </v-row>
        <v-row>
          <v-col cols="6" md="2" class="d-flex align-center">
            <p>
              <v-icon :size="20">mdi-truck-delivery-outline</v-icon> Le livreur :
            </p>
          </v-col>
          <v-col cols="6" md="4">
            <span v-show="!loadingLivreur && !showEditLivreur">
              <v-chip color="primary" link @click="clicLivreur(livreurId)">
                <p>
                  {{ livreurName }}
                  <v-tooltip open-delay="500" activator="parent" location="top">{{
                    livreurId
                  }}</v-tooltip>
                  <v-icon :size="20">mdi-chevron-right</v-icon>
                </p>
              </v-chip>
              <v-btn
                v-if="admin"
                class="ml-5 btn-rond pa-0"
                @click.stop="clicEditLivreur()"
                rounded
                ><v-icon :size="20">mdi-account-edit</v-icon></v-btn
              ></span
            >
            <span v-show="!loadingLivreur && showEditLivreur">
              <v-row no-gutters>
                <v-col>
                  <v-combobox
                    class="hide-hint"
                    :loading="userLoading"
                    label="Livreur"
                    return-object
                    v-model="modelLivreur"
                    item-props
                    dense
                    :items="listLivreur"
                    style="width: auto"
                    variant="solo"
                  ></v-combobox>
                </v-col>
                <v-col class="d-flex align-center">
                  <v-btn
                    :disabled="modelLivreur?.id == undefined"
                    class="ml-5 btn-rond pa-0"
                    @click.stop="clicValidateLivreur()"
                    rounded
                    ><v-icon :size="15">mdi-check-bold</v-icon></v-btn
                  >
                </v-col>
              </v-row>
            </span>
            <v-progress-circular
              v-show="loadingLivreur"
              :size="20"
              :width="2"
              indeterminate
              color="primary"
            ></v-progress-circular>
          </v-col>
          <v-col cols="6" md="2">
            <p><v-icon :size="20">mdi-clock-outline</v-icon> Durée :</p>
          </v-col>
          <v-col cols="6" md="2">
            <p>
              <b>{{ formatDuration(tournee?.duree) }}</b>
            </p>
          </v-col>
        </v-row>
        <v-row>
          <v-col cols="6" md="2">
            <p><v-icon :size="20">mdi-package-variant-closed</v-icon> Colis :</p>
          </v-col>
          <v-col cols="6" md="4">
            <p>
              <b>{{ tournee?.nbColis }}</b>
            </p>
          </v-col>
          <v-col cols="6" md="2">
            <p><v-icon :size="20">mdi-map-marker-distance</v-icon> Distance :</p>
          </v-col>
          <v-col cols="6" md="2">
            <p>
              <b>{{ formatDistance(tournee?.distance) }}</b>
            </p>
          </v-col>
        </v-row>
      </v-card>

      <h1 class="px-8">Les colis :</h1>
      <v-card
        ref="cardMap"
        :loading="listLoading"
        elevation="3"
        class="ma-8 pa-8"
      >
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
                  Dernière mise à jour :
                  {{ formatDateTime(location?.lastUpdate) }}
                </p>
                <p>latitude : {{ formatCoordonne(location?.latitude) }}</p>
                <p>longitude : {{ formatCoordonne(location?.longitude) }}</p>
              </div>
            </InfoWindow></Marker
          >
          <Marker
            v-for="colis in listColis"
            v-bind:key="colis.id"
            :options="{
              position: { lat: colis.latitude, lng: colis.longitude },
              label: {
                text: colis.position.toString(),
                color: '#FFFFFF',
                fontSize: '12px',
                fontWeight: 'bold',
                className: 'label-pin',
              },
              title: colis.address,
              icon: {
                url: pinColor(colis.lastStatus.status),
                scaledSize: { width: 40, height: 40 },
              },
            }"
          >
            <InfoWindow>
              <div>
                <h2>
                  <b>{{ colis?.subscriberName }}</b>
                </h2>
                <p>{{ colis?.address }}</p>
                <p>latitude : {{ formatCoordonne(colis?.latitude) }}</p>
                <p>longitude : {{ formatCoordonne(colis?.longitude) }}</p>
              </div>
            </InfoWindow></Marker
          >
          <Polyline
            v-for="colis in listColis"
            v-bind:key="colis.id"
            :options="{
              path: formatPath(decode(colis.polyline)),
              geodesic: true,
              strokeColor: color.secondary,
              strokeOpacity: 1.0,
              strokeWeight: 6,
            }"
          />
          <Polyline
            v-for="colis in listColis"
            v-bind:key="colis.id"
            :options="{
              path: formatPath(decode(colis.polyline)),
              geodesic: true,
              strokeColor: color.primary,
              strokeOpacity: 1.0,
              strokeWeight: 3,
            }"
          />
        </GoogleMap>
      </v-card>
      <v-card :loading="listLoading" elevation="3" class="ma-8 pa-8">
        <v-table>
          <thead>
            <tr>
              <th class="text-left">#</th>
              <th class="text-left">Abonné</th>
              <th class="text-left">Status</th>
              <th class="text-left">Dernière mise à jour</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="colis in listColis"
              :key="colis.id"
              class="clickable"
              @click="clickColis(colis.id)"
            >
              <td>
                <v-btn
                  class="btn-position"
                  @click.stop="clickNumColis(colis)"
                  rounded
                  ><b>{{ colis.position }}</b></v-btn
                >
              </td>
              <td>
                <v-chip
                  v-if="colis.subscriber != null"
                  color="primary"
                  link
                  @click.stop="clicSubscriber(colis.subscriber.id)"
                  >{{ colis.subscriberName }}
                  <v-icon :size="20">mdi-chevron-right</v-icon>
                  <v-tooltip open-delay="500" activator="parent" location="top">
                    <div class="container-qr">
                      <qrcode-vue
                        ref="qrcode"
                        :value="colis.id"
                        :size="200"
                      ></qrcode-vue></div></v-tooltip
                ></v-chip>
                <p v-else>{{ colis.subscriberName }}</p>
              </td>
              <td>
                <v-chip :color="statusColor(colis.lastStatus.status)">
                  {{ statusName(colis.lastStatus.status) }}
                </v-chip>
              </td>
              <td>{{ formatDateTime(colis.lastStatus.createdAt) }}</td>
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
              @click="clicLoadMoreColis"
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
                >Supprimer la tournée</v-btn
              >
            </template>

            <v-card title="Confirmez suppression">
              <v-card-text>
                Etes-vous certain de vouloir supprimer cette tournée ? Cela
                supprimera toutes les colis associées.
                <v-col cols="12">
                  <v-text-field
                    label="Tapez « oui » pour pouvoir valider"
                    @input="onConfirmRemoveChange"
                    variant="solo"
                  ></v-text-field>
                </v-col>
              </v-card-text>

              <v-card-actions>
                <v-spacer />

                <v-btn text="Annuler" @click="dialogRemove = false" />
                <v-btn
                  text="Valider"
                  :disabled="!verifRemove"
                  @click="clicBtnRemove(tournee.id, tournee.missionTourneeId)"
                />
              </v-card-actions>
            </v-card>
          </v-dialog>
        </v-col>
      </v-row>
    </v-card>
  </div>
</template>

<style scoped>
.btn-position {
  min-width: 38px;
  padding: 0;
  font-weight: bold;
}
.btn-rond {
  min-width: 32px;
  height: 32px !important;
  padding: 0;
}
.loader {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100%;
  height: 100%;
}

.container-qr {
  padding: 10px !important;
  padding-bottom: 5px !important;
  background-color: #ffffff;
  border-radius: 5px;
}
</style>

<style>
.label-pin {
  padding-bottom: 17px;
}
.v-tooltip > .v-overlay__content {
  padding: 10px !important;
}
.hide-hint .v-input__details {
  display: none !important;
}
</style>
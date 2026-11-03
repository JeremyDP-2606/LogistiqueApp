<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { getUsername, getMail, getClientName, isAdmin } from "@/util/auth";
import { color } from "@/util/const";
import sha256 from "crypto-js/sha256";
import { Auth } from "@aws-amplify/auth";
import router from "@/router";
import { useRoute } from "vue-router";

const railDrawer = ref(window.innerWidth <= 1024);
const forceRail = ref(false);
const expandOnHover = ref(true);
const drawer = ref(true);
const username = ref("");
const clientName = ref(null);
const email = ref("");
const urlGravatar = ref("");
const userIsAdmin = ref(false); // État pour vérifier si l'utilisateur est admin
const isActive = (path) => useRoute().path.startsWith(path);

onMounted(async () => {
  username.value = await getUsername();
  const mail = await getMail();
  clientName.value = await getClientName();
  email.value = mail;
  const hashMail = sha256(String(mail).trim().toLowerCase());
  urlGravatar.value =
    "https://www.gravatar.com/avatar/" + hashMail + "?d=identicon&s=128";

  // Vérifie si l'utilisateur est un administrateur
  userIsAdmin.value = await isAdmin();
  window.addEventListener("resize", eventResize);
});

onUnmounted(() => {
  window.removeEventListener("resize", eventResize);
});

const eventResize = () => {
  railDrawer.value = window.innerWidth <= 1024;
};

const logout = async () => {
  try {
    await Auth.signOut();
    router.replace("/");
  } catch (error) {
    console.error("Erreur lors de la déconnexion:", error);
  }
};

const closeDrawer = () => {
  forceRail.value = true;
  expandOnHover.value = false;
  setTimeout(function () {
    expandOnHover.value = true;
  }, 500);
};
</script>

<template>
  <v-navigation-drawer
    :expand-on-hover="expandOnHover"
    :rail="railDrawer || forceRail"
    permanent
    v-model="drawer"
  >
    <div class="d-flex flex-column" style="height: 100%">
      <div class="flex-grow-1">
        <v-list>
          <v-list-item
            :prepend-avatar="urlGravatar"
            :title="username"
            :subtitle="clientName"
          >
            <template v-slot:append v-if="!(railDrawer || forceRail)">
              <v-btn
                variant="text"
                icon="mdi-chevron-left"
                @click.stop="closeDrawer"
              ></v-btn>
            </template>
          </v-list-item>
        </v-list>

        <v-divider></v-divider>

        <v-list-item-group class="menu-group">
          <div class="px-2">
            <v-list-item
              prepend-icon="mdi-package-variant-closed"
              title="Missions"
              value="missions"
              to="/missions"
              :class="{ 'v-list-item--active': (isActive('/mission') || isActive('/tournee') || isActive('/colis')) }"
              :style="{ color: (isActive('/mission') || isActive('/tournee') || isActive('/colis')) ? color.primary : '' }"
            ></v-list-item>
            <v-list-item
              prepend-icon="mdi-truck-delivery-outline"
              title="Utilisateurs"
              value="utilisateurs"
              to="/users"
              :class="{ 'v-list-item--active': isActive('/user') }"
              :style="{ color: isActive('/user') ? color.primary : '' }"
            ></v-list-item>
            <v-list-item
              prepend-icon="mdi-account-group"
              title="Abonnés"
              value="abonnes"
              to="/subscribers"
              :class="{ 'v-list-item--active': isActive('/subscriber') }"
              :style="{ color: isActive('/subscriber') ? color.primary : '' }"
            ></v-list-item>
            <v-list-item
              prepend-icon="mdi-account-multiple-plus"
              title="Ajout Abonnés"
              value="ajout-abonnes"
              to="/addsubscriber"
              :class="{ 'v-list-item--active': isActive('/addsubscriber') }"
              :style="{ color: isActive('/addsubscriber') ? color.primary : '' }"
            ></v-list-item>
            <v-list-item
              v-if="userIsAdmin"
              prepend-icon="mdi-calculator"
              title="Statistiques"
              value="statistics"
              to="/statistics"
              :class="{ 'v-list-item--active': isActive('/statistics') }"
              :style="{ color: isActive('/statistics') ? color.primary : '' }"
            ></v-list-item>
          </div>
          
        </v-list-item-group>
      </div>

      <v-list density="compact" nav>
        <v-list-item
          @click="logout"
          prepend-icon="mdi-logout"
          title="Déconnexion"
          value="logout"
        ></v-list-item>
      </v-list>
    </div>
  </v-navigation-drawer>

  <v-main>
    <router-view></router-view>
  </v-main>
</template>

<style lang="css" scoped>
.menu-group .v-list-item {
  min-height: 48px;
  margin-bottom: 8px;
  border-radius: 4px;
  padding: 8px;
}

.menu-group {
  padding-inline-start: 8px !important;
  padding-inline-end: 8px !important;
}
</style>

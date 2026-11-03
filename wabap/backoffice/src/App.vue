<script setup>
import { ref, provide } from "vue";

const errorMessage = ref("");
const snackbarVisible = ref(false);

function showError(msg) {
  errorMessage.value = msg;
  snackbarVisible.value = true;
  console.log("showError("+msg+")")
}

provide("showError", showError);
</script>

<template>
  <v-app>
    <router-view></router-view>

    <v-snackbar
      v-model="snackbarVisible"
      :timeout="3000"
      color="red-accent-4"
      elevation="24"
      >{{ errorMessage }}</v-snackbar
    >
  </v-app>
</template>

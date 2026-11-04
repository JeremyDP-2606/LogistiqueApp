window.global = window

import "./assets/main.css";
import "@mdi/font/css/materialdesignicons.min.css";

import { createApp } from "vue";
import App from "./App.vue";


const app = createApp(App);

// Router
import router from "./router";
app.use(router);

// Vuetify
import "vuetify/styles";
import { createVuetify } from "vuetify";
import * as components from "vuetify/components";
import * as directives from "vuetify/directives";
import { color } from "@/util/const";
const myCustomLightTheme = {
  dark: false,
  colors: {
    primary: color.primary,
  },
};
app.use(
  createVuetify({
    components,
    directives,
    theme: {
      defaultTheme: "myCustomLightTheme",
      themes: {
        myCustomLightTheme,
      },
    },
  })
);

app.mount("#app");

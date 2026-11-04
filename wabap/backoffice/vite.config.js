import { fileURLToPath, URL } from "node:url";

import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  // amazon-cognito-identity-js attend la variable Node « global »
  define: { global: "globalThis" },
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  build: {
    rollupOptions: {},
    minify: true,
    sourcemap: false,
    commonjsOptions: { include: [] },
  },
  optimizeDeps: {
    disabled: false,
  },
});

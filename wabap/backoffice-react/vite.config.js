import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: { port: 5174 },
  // amazon-cognito-identity-js attend la variable Node « global »
  define: { global: 'globalThis' },
});

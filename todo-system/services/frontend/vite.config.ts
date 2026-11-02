import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Inner loop: services run via ./gradlew bootRun (8081, 8082); nginx does this routing in the container.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api/todos': 'http://localhost:8081',
      '/api/activity': 'http://localhost:8082',
    },
  },
})

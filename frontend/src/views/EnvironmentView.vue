<script setup>
import { ref, onMounted } from 'vue'
import { useBackendStore } from '../stores/backend'
import { api } from '../services/api'

const backendStore = useBackendStore()
const headers = ref(null)
const loading = ref(true)
const frontendConfig = {
  apiBaseUrl: import.meta.env.VITE_API_URL || 'http://localhost:8080',
  mode: import.meta.env.MODE,
  baseUrl: import.meta.env.BASE_URL,
}

onMounted(async () => {
  try {
    await backendStore.fetchEnvironment()
    const res = await api.getHeaders()
    headers.value = res.data
  } catch (error) {
    console.error('Failed to fetch environment data:', error)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-3xl font-bold text-white mb-2">Environment</h2>
      <p class="text-slate-400">Runtime configuration and request details</p>
    </div>

    <div v-if="loading" class="text-center text-slate-400 py-12">
      Loading environment data...
    </div>

    <template v-else>
      <!-- Environment Variables -->
      <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-white mb-4">Environment Variables</h3>
        <div v-if="backendStore.environment" class="space-y-2 max-h-96 overflow-y-auto">
          <div
            v-for="(value, key) in backendStore.environment"
            :key="key"
            class="flex gap-4 py-2 border-b border-slate-700 last:border-0"
          >
            <span class="text-slate-400 font-mono text-sm w-1/3">{{ key }}</span>
            <span class="text-white font-mono text-sm flex-1 break-all">{{ value }}</span>
          </div>
        </div>
        <div v-else class="text-slate-400 text-sm">
          No environment variables available
        </div>
      </div>

      <!-- Request Headers -->
      <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-white mb-4">Request Headers</h3>
        <div v-if="headers" class="space-y-2">
          <div
            v-for="(value, key) in headers"
            :key="key"
            class="flex gap-4 py-2 border-b border-slate-700 last:border-0"
          >
            <span class="text-slate-400 font-mono text-sm w-1/3">{{ key }}</span>
            <span class="text-white font-mono text-sm flex-1 break-all">{{ value }}</span>
          </div>
        </div>
        <div v-else class="text-slate-400 text-sm">
          No headers available
        </div>
      </div>

      <!-- Frontend Config -->
      <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-white mb-4">Frontend Configuration</h3>
        <div class="space-y-2">
          <div class="flex gap-4 py-2 border-b border-slate-700">
            <span class="text-slate-400 font-mono text-sm w-1/3">API Base URL</span>
            <span class="text-white font-mono text-sm flex-1">
              {{ frontendConfig.apiBaseUrl }}
            </span>
          </div>
          <div class="flex gap-4 py-2 border-b border-slate-700">
            <span class="text-slate-400 font-mono text-sm w-1/3">Mode</span>
            <span class="text-white font-mono text-sm flex-1">
              {{ frontendConfig.mode }}
            </span>
          </div>
          <div class="flex gap-4 py-2">
            <span class="text-slate-400 font-mono text-sm w-1/3">Base URL</span>
            <span class="text-white font-mono text-sm flex-1">
              {{ frontendConfig.baseUrl }}
            </span>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>

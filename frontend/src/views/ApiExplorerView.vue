<script setup>
import { ref, onMounted } from 'vue'
import { api } from '../services/api'

const openApiSpec = ref(null)
const loading = ref(true)
const selectedEndpoint = ref(null)
const response = ref(null)

onMounted(async () => {
  try {
    const res = await api.getOpenAPI()
    openApiSpec.value = res.data
  } catch (error) {
    console.error('Failed to fetch OpenAPI spec:', error)
  } finally {
    loading.value = false
  }
})

async function testEndpoint(path, method) {
  selectedEndpoint.value = { path, method }
  response.value = { loading: true }

  try {
    let result
    switch (path) {
      case '/healthz':
        result = await api.getHealth()
        break
      case '/readyz':
        result = await api.getReady()
        break
      case '/livez':
        result = await api.getLive()
        break
      case '/version':
        result = await api.getVersion()
        break
      case '/env':
        result = await api.getEnv()
        break
      case '/headers':
        result = await api.getHeaders()
        break
      case '/metrics':
        result = await api.getMetrics()
        break
      default:
        result = { data: 'Click endpoint to test' }
    }

    response.value = {
      loading: false,
      status: result.status,
      data: result.data,
    }
  } catch (error) {
    response.value = {
      loading: false,
      status: error.response?.status || 'Error',
      data: error.message,
    }
  }
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-3xl font-bold text-white mb-2">API Explorer</h2>
      <p class="text-slate-400">Test and explore backend API endpoints</p>
    </div>

    <div v-if="loading" class="text-center text-slate-400 py-12">
      Loading API specification...
    </div>

    <div v-else-if="openApiSpec" class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Endpoints List -->
      <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-white mb-4">Endpoints</h3>
        <div class="space-y-2">
          <div
            v-for="(methods, path) in openApiSpec.paths"
            :key="path"
            class="border border-slate-600 rounded-lg overflow-hidden"
          >
            <div
              v-for="(config, method) in methods"
              :key="method"
              @click="testEndpoint(path, method)"
              class="flex items-center justify-between p-3 hover:bg-slate-700 cursor-pointer transition-colors"
            >
              <div class="flex items-center gap-3">
                <span
                  :class="[
                    'px-2 py-1 text-xs font-bold rounded uppercase',
                    method === 'get' ? 'bg-blue-600' : 'bg-green-600'
                  ]"
                >
                  {{ method }}
                </span>
                <span class="text-white font-mono text-sm">{{ path }}</span>
              </div>
              <span class="text-slate-400 text-sm">→</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Response Viewer -->
      <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
        <h3 class="text-lg font-semibold text-white mb-4">Response</h3>

        <div v-if="!selectedEndpoint" class="text-center text-slate-400 py-12">
          Select an endpoint to test
        </div>

        <div v-else-if="response?.loading" class="text-center text-slate-400 py-12">
          Sending request...
        </div>

        <div v-else-if="response" class="space-y-4">
          <!-- Status -->
          <div class="flex items-center gap-2">
            <span class="text-sm text-slate-400">Status:</span>
            <span
              :class="[
                'px-3 py-1 rounded-lg font-semibold',
                response.status >= 200 && response.status < 300
                  ? 'bg-green-900/50 text-green-400'
                  : 'bg-red-900/50 text-red-400'
              ]"
            >
              {{ response.status }}
            </span>
          </div>

          <!-- Request Info -->
          <div class="border border-slate-600 rounded-lg p-3 bg-slate-900">
            <div class="text-xs text-slate-400 mb-1">Request</div>
            <div class="font-mono text-sm text-white">
              {{ selectedEndpoint.method.toUpperCase() }} {{ selectedEndpoint.path }}
            </div>
          </div>

          <!-- Response Body -->
          <div class="border border-slate-600 rounded-lg p-3 bg-slate-900">
            <div class="text-xs text-slate-400 mb-2">Response Body</div>
            <pre class="text-xs text-green-400 font-mono overflow-x-auto">{{ typeof response.data === 'string' ? response.data : JSON.stringify(response.data, null, 2) }}</pre>
          </div>
        </div>
      </div>
    </div>

    <!-- API Info -->
    <div v-if="openApiSpec" class="bg-slate-800 rounded-lg border border-slate-700 p-6">
      <h3 class="text-lg font-semibold text-white mb-4">API Information</h3>
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span class="text-slate-400">Title:</span>
          <span class="ml-2 text-white">{{ openApiSpec.info.title }}</span>
        </div>
        <div>
          <span class="text-slate-400">Version:</span>
          <span class="ml-2 text-white">{{ openApiSpec.info.version }}</span>
        </div>
        <div class="col-span-2">
          <span class="text-slate-400">Description:</span>
          <span class="ml-2 text-white">{{ openApiSpec.info.description }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

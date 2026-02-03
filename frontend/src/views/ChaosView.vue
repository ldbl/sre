<script setup>
import { ref } from 'vue'
import { useBackendStore } from '../stores/backend'
import { api } from '../services/api'

const backendStore = useBackendStore()
const delaySeconds = ref(2)
const statusCode = ref(500)
const message = ref('')

async function toggleReadiness(enable) {
  try {
    await backendStore.toggleReady(enable)
    message.value = `Readiness ${enable ? 'enabled' : 'disabled'} successfully`
    setTimeout(() => message.value = '', 3000)
  } catch (error) {
    message.value = `Error: ${error.message}`
  }
}

async function toggleLiveness(enable) {
  try {
    await backendStore.toggleLive(enable)
    message.value = `Liveness ${enable ? 'enabled' : 'disabled'} successfully`
    setTimeout(() => message.value = '', 3000)
  } catch (error) {
    message.value = `Error: ${error.message}`
  }
}

async function triggerDelay() {
  try {
    message.value = `Triggering ${delaySeconds.value}s delay...`
    await api.delay(delaySeconds.value)
    message.value = `Delay completed successfully`
    setTimeout(() => message.value = '', 3000)
  } catch (error) {
    message.value = `Error: ${error.message}`
  }
}

async function triggerStatus() {
  try {
    message.value = `Triggering HTTP ${statusCode.value}...`
    await api.status(statusCode.value)
    message.value = `Received status ${statusCode.value}`
    setTimeout(() => message.value = '', 3000)
  } catch (error) {
    message.value = `Error: ${error.message}`
  }
}

async function triggerPanic() {
  if (!confirm('This will terminate the backend process. Are you sure?')) return

  try {
    message.value = 'Triggering panic... Backend will restart'
    await backendStore.triggerPanic()
  } catch (error) {
    message.value = 'Backend terminated (expected behavior)'
  }
}
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-3xl font-bold text-white mb-2">Chaos Engineering</h2>
      <p class="text-slate-400">Test resilience and failure scenarios</p>
    </div>

    <!-- Message Alert -->
    <div v-if="message" class="bg-blue-900/50 border border-blue-700 rounded-lg p-4 text-blue-300">
      {{ message }}
    </div>

    <!-- Probe Controls -->
    <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
      <h3 class="text-lg font-semibold text-white mb-4">Health Probe Controls</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <h4 class="text-sm font-medium text-slate-300 mb-3">Readiness Probe</h4>
          <div class="flex gap-2">
            <button
              @click="toggleReadiness(true)"
              class="flex-1 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors"
            >
              Enable
            </button>
            <button
              @click="toggleReadiness(false)"
              class="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors"
            >
              Disable
            </button>
          </div>
          <p class="mt-2 text-xs text-slate-400">
            Controls whether the service accepts traffic
          </p>
        </div>

        <div>
          <h4 class="text-sm font-medium text-slate-300 mb-3">Liveness Probe</h4>
          <div class="flex gap-2">
            <button
              @click="toggleLiveness(true)"
              class="flex-1 px-4 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg transition-colors"
            >
              Enable
            </button>
            <button
              @click="toggleLiveness(false)"
              class="flex-1 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors"
            >
              Disable
            </button>
          </div>
          <p class="mt-2 text-xs text-slate-400">
            Controls whether Kubernetes should restart the pod
          </p>
        </div>
      </div>
    </div>

    <!-- Delay Injection -->
    <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
      <h3 class="text-lg font-semibold text-white mb-4">Response Delay</h3>
      <div class="flex items-end gap-4">
        <div class="flex-1">
          <label class="block text-sm font-medium text-slate-300 mb-2">
            Delay (seconds)
          </label>
          <input
            v-model.number="delaySeconds"
            type="number"
            min="0"
            max="30"
            step="0.5"
            class="w-full px-4 py-2 bg-slate-700 text-white rounded-lg border border-slate-600 focus:border-blue-500 focus:outline-none"
          />
        </div>
        <button
          @click="triggerDelay"
          class="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
        >
          Trigger Delay
        </button>
      </div>
      <p class="mt-2 text-xs text-slate-400">
        Artificially delay the response to test timeout handling
      </p>
    </div>

    <!-- Status Code -->
    <div class="bg-slate-800 rounded-lg border border-slate-700 p-6">
      <h3 class="text-lg font-semibold text-white mb-4">HTTP Status Code</h3>
      <div class="flex items-end gap-4">
        <div class="flex-1">
          <label class="block text-sm font-medium text-slate-300 mb-2">
            Status Code
          </label>
          <input
            v-model.number="statusCode"
            type="number"
            min="100"
            max="599"
            class="w-full px-4 py-2 bg-slate-700 text-white rounded-lg border border-slate-600 focus:border-blue-500 focus:outline-none"
          />
        </div>
        <button
          @click="triggerStatus"
          class="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
        >
          Trigger Status
        </button>
      </div>
      <p class="mt-2 text-xs text-slate-400">
        Return a specific HTTP status code to test error handling
      </p>
    </div>

    <!-- Panic / Crash -->
    <div class="bg-slate-800 rounded-lg border border-red-900/50 p-6">
      <h3 class="text-lg font-semibold text-red-400 mb-4">⚠️ Crash Simulation</h3>
      <button
        @click="triggerPanic"
        class="px-6 py-3 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors font-semibold"
      >
        💥 Trigger Panic (Terminate Process)
      </button>
      <p class="mt-3 text-sm text-red-300">
        This will immediately terminate the backend process with exit code 255.
        In Kubernetes, the pod will be automatically restarted.
      </p>
    </div>
  </div>
</template>

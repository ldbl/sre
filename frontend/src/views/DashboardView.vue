<script setup>
import { onMounted, onUnmounted, ref, computed } from 'vue'
import { useBackendStore } from '../stores/backend'
import HealthCard from '../components/Dashboard/HealthCard.vue'
import StatsCard from '../components/Dashboard/StatsCard.vue'

const backendStore = useBackendStore()
const refreshInterval = ref(null)
const loading = ref(true)

// Computed stats from metrics
const totalRequests = computed(() => {
  if (!backendStore.metrics || !backendStore.metrics.app_http_requests_total) return 0
  return backendStore.metrics.app_http_requests_total
    .reduce((sum, m) => sum + m.value, 0)
})

const inFlightRequests = computed(() => {
  if (!backendStore.metrics || !backendStore.metrics.app_http_in_flight_requests) return 0
  return backendStore.metrics.app_http_in_flight_requests[0]?.value || 0
})

const avgDuration = computed(() => {
  if (!backendStore.metrics || !backendStore.metrics.app_http_request_duration_seconds_sum) return 0
  const sum = backendStore.metrics.app_http_request_duration_seconds_sum?.[0]?.value || 0
  const count = backendStore.metrics.app_http_request_duration_seconds_count?.[0]?.value || 1
  return (sum / count * 1000).toFixed(2) // Convert to ms
})

async function fetchData() {
  try {
    await Promise.all([
      backendStore.fetchVersion(),
      backendStore.fetchHealth(),
      backendStore.fetchMetrics(),
    ])
  } catch (error) {
    console.error('Failed to fetch data:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchData()
  // Refresh every 5 seconds
  refreshInterval.value = setInterval(fetchData, 5000)
})

onUnmounted(() => {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value)
  }
})
</script>

<template>
  <div class="space-y-6">
    <div>
      <h2 class="text-3xl font-bold text-white mb-2">Dashboard</h2>
      <p class="text-slate-400">Real-time monitoring of backend services</p>
    </div>

    <!-- Health Status -->
    <div>
      <h3 class="text-lg font-semibold text-white mb-4">Health Status</h3>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <HealthCard
          title="Health Check"
          :status="backendStore.health.healthy"
          :loading="loading"
        />
        <HealthCard
          title="Readiness Probe"
          :status="backendStore.health.ready"
          :loading="loading"
        />
        <HealthCard
          title="Liveness Probe"
          :status="backendStore.health.live"
          :loading="loading"
        />
      </div>
    </div>

    <!-- Metrics -->
    <div>
      <h3 class="text-lg font-semibold text-white mb-4">Metrics</h3>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatsCard
          title="Total Requests"
          :value="totalRequests.toLocaleString()"
          icon="📈"
          trend="All time"
        />
        <StatsCard
          title="In-Flight Requests"
          :value="inFlightRequests"
          icon="🔄"
          trend="Current"
        />
        <StatsCard
          title="Avg Response Time"
          :value="`${avgDuration}ms`"
          icon="⚡"
          trend="Per request"
        />
      </div>
    </div>

    <!-- Version Info -->
    <div v-if="backendStore.version" class="bg-slate-800 rounded-lg border border-slate-700 p-6">
      <h3 class="text-lg font-semibold text-white mb-4">Backend Version</h3>
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span class="text-slate-400">Version:</span>
          <span class="ml-2 text-white">{{ backendStore.version.version || 'dev' }}</span>
        </div>
        <div>
          <span class="text-slate-400">Commit:</span>
          <span class="ml-2 text-white font-mono">{{ backendStore.version.commit_short }}</span>
        </div>
        <div class="col-span-2">
          <span class="text-slate-400">Build Time:</span>
          <span class="ml-2 text-white">{{ backendStore.version.build_time || 'N/A' }}</span>
        </div>
      </div>
    </div>

    <!-- Auto-refresh indicator -->
    <div class="text-center text-sm text-slate-500">
      Auto-refreshing every 5 seconds
    </div>
  </div>
</template>

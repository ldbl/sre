import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { api } from '../services/api'

export const useBackendStore = defineStore('backend', () => {
  // State
  const version = ref(null)
  const health = ref({ healthy: false, ready: false, live: false })
  const metrics = ref(null)
  const environment = ref(null)
  const loading = ref(false)
  const error = ref(null)

  // Computed
  const isHealthy = computed(() => health.value.healthy && health.value.ready && health.value.live)
  const healthStatus = computed(() => {
    if (!health.value.healthy) return 'unhealthy'
    if (!health.value.ready) return 'not-ready'
    if (!health.value.live) return 'not-live'
    return 'healthy'
  })

  // Actions
  async function fetchVersion() {
    try {
      const response = await api.getVersion()
      version.value = response.data
    } catch (err) {
      console.error('Failed to fetch version:', err)
      error.value = err.message
    }
  }

  async function fetchHealth() {
    try {
      const [healthRes, readyRes, liveRes] = await Promise.all([
        api.getHealth().catch(() => ({ status: 503 })),
        api.getReady().catch(() => ({ status: 503 })),
        api.getLive().catch(() => ({ status: 503 })),
      ])

      health.value = {
        healthy: healthRes.status === 200,
        ready: readyRes.status === 200,
        live: liveRes.status === 200,
      }
    } catch (err) {
      console.error('Failed to fetch health:', err)
      health.value = { healthy: false, ready: false, live: false }
    }
  }

  async function fetchMetrics() {
    try {
      const response = await api.getMetrics()
      metrics.value = parsePrometheusMetrics(response.data)
    } catch (err) {
      console.error('Failed to fetch metrics:', err)
      error.value = err.message
    }
  }

  async function fetchEnvironment() {
    try {
      const response = await api.getEnv()
      environment.value = response.data
    } catch (err) {
      console.error('Failed to fetch environment:', err)
      error.value = err.message
    }
  }

  async function toggleReady(enable) {
    try {
      if (enable) {
        await api.enableReady()
      } else {
        await api.disableReady()
      }
      await fetchHealth()
    } catch (err) {
      console.error('Failed to toggle ready:', err)
      error.value = err.message
    }
  }

  async function toggleLive(enable) {
    try {
      if (enable) {
        await api.enableLive()
      } else {
        await api.disableLive()
      }
      await fetchHealth()
    } catch (err) {
      console.error('Failed to toggle live:', err)
      error.value = err.message
    }
  }

  async function triggerPanic() {
    try {
      await api.triggerPanic()
    } catch (err) {
      console.error('Failed to trigger panic:', err)
      error.value = err.message
    }
  }

  // Helper function to parse Prometheus metrics
  function parsePrometheusMetrics(metricsText) {
    const metrics = {}
    const lines = metricsText.split('\n')

    for (const line of lines) {
      if (line.startsWith('#') || line.trim() === '') continue

      const match = line.match(/^([a-zA-Z_:][a-zA-Z0-9_:]*(?:\{[^}]*\})?) (.+)$/)
      if (match) {
        const [, metricName, value] = match
        const name = metricName.split('{')[0]

        if (!metrics[name]) {
          metrics[name] = []
        }
        metrics[name].push({
          name: metricName,
          value: parseFloat(value),
        })
      }
    }

    return metrics
  }

  return {
    // State
    version,
    health,
    metrics,
    environment,
    loading,
    error,
    // Computed
    isHealthy,
    healthStatus,
    // Actions
    fetchVersion,
    fetchHealth,
    fetchMetrics,
    fetchEnvironment,
    toggleReady,
    toggleLive,
    triggerPanic,
  }
})

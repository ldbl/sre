import axios from 'axios'

// Get backend URL from environment or default to localhost
const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080'

// Create axios instance with default config
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor
apiClient.interceptors.request.use(
  (config) => {
    console.log(`[API] ${config.method.toUpperCase()} ${config.url}`)
    return config
  },
  (error) => {
    console.error('[API] Request error:', error)
    return Promise.reject(error)
  }
)

// Response interceptor
apiClient.interceptors.response.use(
  (response) => {
    console.log(`[API] ${response.status} ${response.config.url}`)
    return response
  },
  (error) => {
    console.error('[API] Response error:', error.message)
    return Promise.reject(error)
  }
)

// API methods
export const api = {
  // Health checks
  getHealth() {
    return apiClient.get('/healthz')
  },

  getReady() {
    return apiClient.get('/readyz')
  },

  enableReady() {
    return apiClient.put('/readyz/enable')
  },

  disableReady() {
    return apiClient.put('/readyz/disable')
  },

  getLive() {
    return apiClient.get('/livez')
  },

  enableLive() {
    return apiClient.put('/livez/enable')
  },

  disableLive() {
    return apiClient.put('/livez/disable')
  },

  // Version and info
  getVersion() {
    return apiClient.get('/version')
  },

  getEnv() {
    return apiClient.get('/env')
  },

  getHeaders() {
    return apiClient.get('/headers')
  },

  // Metrics
  getMetrics() {
    return apiClient.get('/metrics', {
      headers: { 'Accept': 'text/plain' },
      transformResponse: [(data) => data], // Keep as plain text
    })
  },

  // OpenAPI spec
  getOpenAPI() {
    return apiClient.get('/openapi')
  },

  // Chaos engineering
  triggerPanic() {
    return apiClient.get('/panic')
  },

  delay(seconds) {
    return apiClient.get(`/delay/${seconds}`)
  },

  status(code) {
    return apiClient.get(`/status/${code}`, {
      validateStatus: () => true, // Accept any status
    })
  },

  echo(body, contentType = 'application/json') {
    return apiClient.post('/echo', body, {
      headers: { 'Content-Type': contentType },
    })
  },
}

export default apiClient

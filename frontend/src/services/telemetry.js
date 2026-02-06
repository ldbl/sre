import { WebTracerProvider } from '@opentelemetry/sdk-trace-web'
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http'
import { trace } from '@opentelemetry/api'
import { resourceFromAttributes } from '@opentelemetry/resources'
import { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } from '@opentelemetry/semantic-conventions'
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-web'
import { registerInstrumentations } from '@opentelemetry/instrumentation'
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch'
import { XMLHttpRequestInstrumentation } from '@opentelemetry/instrumentation-xml-http-request'
import { DocumentLoadInstrumentation } from '@opentelemetry/instrumentation-document-load'
import { UserInteractionInstrumentation } from '@opentelemetry/instrumentation-user-interaction'

// Get configuration from environment
const getConfig = () => {
  // Uptrace DSN format: https://TOKEN@api.uptrace.dev
  const uptraceDsn = window.__ENV__?.VITE_UPTRACE_DSN || import.meta.env.VITE_UPTRACE_DSN || ''

  let collectorUrl = window.__ENV__?.VITE_OTEL_COLLECTOR_URL || import.meta.env.VITE_OTEL_COLLECTOR_URL || 'http://localhost:4318/v1/traces'
  let headers = {}

  // If Uptrace DSN is set, use Uptrace directly
  if (uptraceDsn) {
    collectorUrl = 'https://api.uptrace.dev/v1/traces'
    // Extract token from DSN (format: https://TOKEN@api.uptrace.dev)
    const match = uptraceDsn.match(/https:\/\/([^@]+)@/)
    if (match) {
      headers['uptrace-dsn'] = uptraceDsn
    }
  }

  return {
    serviceName: 'frontend',
    serviceVersion: '1.0.0',
    environment: window.__ENV__?.ENVIRONMENT || import.meta.env.MODE || 'development',
    collectorUrl,
    headers,
  }
}

export function initTelemetry() {
  const config = getConfig()

  console.log('[Telemetry] Initializing OpenTelemetry...', {
    service: config.serviceName,
    version: config.serviceVersion,
    environment: config.environment,
    collector: config.collectorUrl,
  })

  // Create resource with service metadata
  const resource = resourceFromAttributes({
    [ATTR_SERVICE_NAME]: config.serviceName,
    [ATTR_SERVICE_VERSION]: config.serviceVersion,
    'deployment.environment': config.environment,
  })

  // Create tracer provider
  const provider = new WebTracerProvider({
    resource,
  })

  // Configure OTLP HTTP exporter
  const exporter = new OTLPTraceExporter({
    url: config.collectorUrl,
    headers: config.headers,
  })

  // Add batch span processor
  provider.addSpanProcessor(new BatchSpanProcessor(exporter, {
    maxQueueSize: 100,
    maxExportBatchSize: 10,
    scheduledDelayMillis: 500,
  }))

  // Register the provider
  provider.register()

  // Register auto-instrumentations
  registerInstrumentations({
    instrumentations: [
      // Fetch API instrumentation (for axios and fetch)
      new FetchInstrumentation({
        propagateTraceHeaderCorsUrls: [
          /localhost/,
          /\.local$/,
          /\.svc\.cluster\.local$/,
          /example\.com$/,
        ],
        clearTimingResources: true,
        applyCustomAttributesOnSpan: (span, request, response) => {
          // Add custom attributes to HTTP spans
          if (response) {
            span.setAttribute('http.response.status_code', response.status)
            span.setAttribute('http.response.status_text', response.statusText)
          }
          if (request) {
            span.setAttribute('http.request.method', request.method || 'GET')
          }
        },
      }),

      // XMLHttpRequest instrumentation (backup)
      new XMLHttpRequestInstrumentation({
        propagateTraceHeaderCorsUrls: [
          /localhost/,
          /\.local$/,
          /\.svc\.cluster\.local$/,
          /example\.com$/,
        ],
      }),

      // Document load instrumentation (page load performance)
      new DocumentLoadInstrumentation(),

      // User interaction instrumentation (clicks, etc)
      new UserInteractionInstrumentation({
        eventNames: ['click', 'submit'],
      }),
    ],
  })

  console.log('[Telemetry] OpenTelemetry initialized successfully')

  return provider
}

// Export tracer for manual instrumentation
export function getTracer() {
  return trace.getTracer('frontend', '1.0.0')
}

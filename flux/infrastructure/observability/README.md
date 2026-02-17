# Observability Stack

This directory contains the observability infrastructure for the SRE platform, including Prometheus, Grafana, and Alertmanager.

## Components

### Kube-Prometheus-Stack

The `kube-prometheus-stack` Helm chart provides:

- **Prometheus Operator** - Manages Prometheus, ServiceMonitor, and PrometheusRule resources
- **Prometheus** - Metrics collection and storage
- **Grafana** - Metrics visualization and dashboards
- **Alertmanager** - Alert routing and notification management
- **Node Exporter** - Node-level metrics
- **Kube-State-Metrics** - Kubernetes object metrics

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Observability Namespace                  │
│                                                              │
│  ┌──────────────┐      ┌──────────────┐     ┌────────────┐ │
│  │  Prometheus  │◄─────│ServiceMonitor│────►│  Backend   │ │
│  │              │      └──────────────┘     │  /metrics  │ │
│  │  - 7d retention                          └────────────┘ │
│  │  - 10GB storage │                                        │
│  └──────┬───────┘                                          │
│         │                                                   │
│         │ PromQL queries                                   │
│         ▼                                                   │
│  ┌──────────────┐      ┌──────────────┐                   │
│  │   Grafana    │      │ Alertmanager │                   │
│  │              │      │              │                   │
│  │  - Dashboards│      │  - Alerts    │                   │
│  │  - Explore   │      │  - Routing   │                   │
│  └──────────────┘      └──────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

## Access

### Grafana

**Local Access (port-forward):**
```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80
```

Then open: http://localhost:3000

**Credentials:**
- Username: `admin`
- Password: `admin` (default, change in production!)

**Ingress Access:**
- URL: http://grafana.local (requires `/etc/hosts` entry or DNS)

### Prometheus

**Local Access:**
```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
```

Then open: http://localhost:9090

### Alertmanager

**Local Access:**
```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-alertmanager 9093:9093
```

Then open: http://localhost:9093

## ServiceMonitor Configuration

The backend application exposes Prometheus metrics at `/metrics` endpoint. The ServiceMonitor automatically discovers and scrapes these metrics:

**File:** `flux/apps/backend/base/servicemonitor.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: backend
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

## Dashboards

### Backend Service Metrics

**Dashboard UID:** `backend-metrics`

Pre-configured dashboard showing:

1. **Request Rate by Status** - HTTP requests/sec grouped by status code
2. **Error Rate** - Percentage of 5xx errors
3. **In-Flight Requests** - Current active requests
4. **Request Duration (p50, p95, p99)** - Latency percentiles by endpoint
5. **Memory Usage** - RSS memory and heap allocation
6. **CPU Usage** - Process CPU utilization
7. **Goroutines** - Number of active goroutines

**Location:** `flux/infrastructure/observability/kube-prometheus-stack/backend-dashboard.yaml`

## Alerts

### Backend Alert Rules

**File:** `flux/infrastructure/observability/kube-prometheus-stack/monitoring/backend-alerts.yaml`

SLO recording and burn-rate rules:
- `flux/infrastructure/observability/kube-prometheus-stack/monitoring/backend-slo-rules.yaml`

Configured alerts:

| Alert Name | Severity | Threshold | Description |
|------------|----------|-----------|-------------|
| `BackendHighErrorRate` | warning | >5% errors for 5m | Service experiencing elevated error rate |
| `BackendCriticalErrorRate` | critical | >10% errors for 2m | Service experiencing critical error rate |
| `BackendHighLatency` | warning | p95 >1s for 5m | Service latency is high |
| `BackendServiceDown` | critical | up=0 for 1m | Service is not responding |
| `BackendHighMemoryUsage` | warning | >0.8GB for 5m | Memory usage is high |
| `BackendHighGoroutines` | warning | >10k for 5m | Too many goroutines (possible leak) |
| `BackendPodRestarting` | warning | restarts >0 for 5m | Pod is restarting frequently |
| `BackendSLOErrorBudgetBurnCritical` | critical | burn rate >14.4x | Fast error-budget burn for 99.5% SLO |
| `BackendSLOErrorBudgetBurnWarning` | warning | burn rate >6x | Sustained error-budget burn for 99.5% SLO |

## Metrics Reference

### Backend Application Metrics

All metrics are prefixed with `app_`:

**HTTP Metrics:**
- `app_http_requests_total{method, path, status}` - Total HTTP requests (counter)
- `app_http_request_duration_seconds{method, path}` - Request duration histogram
- `app_http_in_flight_requests` - Current in-flight requests (gauge)

**Go Runtime Metrics:**
- `go_goroutines` - Number of goroutines
- `go_memstats_heap_alloc_bytes` - Heap memory allocated
- `process_resident_memory_bytes` - RSS memory
- `process_cpu_seconds_total` - Total CPU time

## Common PromQL Queries

### Request Rate
```promql
# Total request rate
sum(rate(app_http_requests_total{job="backend"}[5m]))

# Request rate by status
sum(rate(app_http_requests_total{job="backend"}[5m])) by (status)

# Request rate by endpoint
sum(rate(app_http_requests_total{job="backend"}[5m])) by (path)
```

### Error Rate
```promql
# Error rate percentage
(
  sum(rate(app_http_requests_total{job="backend",status=~"5.."}[5m]))
  /
  sum(rate(app_http_requests_total{job="backend"}[5m]))
) * 100
```

### Latency
```promql
# p50 latency
histogram_quantile(0.50,
  sum(rate(app_http_request_duration_seconds_bucket{job="backend"}[5m])) by (le)
)

# p95 latency
histogram_quantile(0.95,
  sum(rate(app_http_request_duration_seconds_bucket{job="backend"}[5m])) by (le)
)

# p99 latency
histogram_quantile(0.99,
  sum(rate(app_http_request_duration_seconds_bucket{job="backend"}[5m])) by (le)
)
```

### Availability (SLI)
```promql
# Availability (based on non-5xx responses)
1 - (
  sum(rate(app_http_requests_total{job="backend",status=~"5.."}[30m]))
  /
  clamp_min(sum(rate(app_http_requests_total{job="backend"}[30m])), 1e-9)
)
```

## Deployment

The observability stack is deployed automatically by Flux:

```bash
# Check deployment status
kubectl get kustomization -n flux-system observability

# Check HelmRelease
kubectl get helmrelease -n observability

# Check all pods
kubectl get pods -n observability

# Check Prometheus targets
kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
# Then visit: http://localhost:9090/targets
```

## Troubleshooting

### Prometheus not scraping backend

1. Check ServiceMonitor:
```bash
kubectl get servicemonitor -n develop backend -o yaml
```

2. Check if backend service has correct labels:
```bash
kubectl get svc -n develop backend -o yaml
```

3. Check Prometheus targets:
```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/targets
# Search for "backend"
```

### Grafana dashboard not showing data

1. Check data source configuration:
   - Login to Grafana
   - Go to Configuration → Data Sources
   - Verify Prometheus is configured and working

2. Test PromQL query directly in Prometheus:
```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/graph
# Run: app_http_requests_total
```

3. Check time range in Grafana (default: last 1 hour)

### Alerts not firing

1. Check PrometheusRule:
```bash
kubectl get prometheusrule -n observability backend-alerts -o yaml
```

2. Check alert status in Prometheus:
```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
# Visit: http://localhost:9090/alerts
```

3. Check Alertmanager:
```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-alertmanager 9093:9093
# Visit: http://localhost:9093
```

## Storage

Prometheus data is stored in a PersistentVolumeClaim:

- **Retention:** 7 days
- **Size:** 10GB
- **Storage Class:** Default (kind uses local-path)

To increase retention or storage:

Edit `flux/infrastructure/observability/kube-prometheus-stack/release.yaml`:

```yaml
prometheus:
  prometheusSpec:
    retention: 30d          # Increase retention
    retentionSize: "50GB"   # Increase size limit
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 50Gi  # Increase PVC size
```

## Production Considerations

For production deployments, consider:

1. **Security:**
   - Change Grafana admin password
   - Enable authentication for Prometheus and Alertmanager
   - Use TLS for ingress

2. **High Availability:**
   - Run multiple Prometheus replicas
   - Use Thanos for long-term storage
   - Run Alertmanager in HA mode

3. **Resource Limits:**
   - Adjust resource requests/limits based on actual usage
   - Monitor Prometheus memory usage (can grow with cardinality)

4. **Alerting:**
   - Configure real notification channels (Slack, PagerDuty, email)
   - Set up escalation policies
   - Test alert routing regularly

5. **Retention:**
   - Adjust retention based on compliance requirements
   - Consider long-term storage with Thanos or Cortex

## Resources

- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Kube-Prometheus-Stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Documentation](https://grafana.com/docs/)

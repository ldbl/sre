# Observability Stack

This directory contains the observability infrastructure for the SRE platform, including Prometheus, Grafana, and k8s-ai-monitor.

## Components

### Kube-Prometheus-Stack

The `kube-prometheus-stack` Helm chart provides:

- **Prometheus Operator** - Manages Prometheus, ServiceMonitor, and PrometheusRule resources
- **Prometheus** - Metrics collection and storage
- **Grafana** - Metrics visualization and dashboards
- **Node Exporter** - Node-level metrics
- **Kube-State-Metrics** - Kubernetes object metrics

### The Guardian (`k8s-ai-monitor`, Chapter 14)

- **Input:** Alertmanager hands it every alert (`k8s-ai-monitor/alertmanager-guardian.yaml`,
  webhook to `POST /alertmanager` with a Bearer token); its own scanners, Kubernetes Warning events
  and Flux stalls feed the same pipeline.
- **One incident per problem:** fingerprints, cooldowns, escalation; a resolved alert closes it.
- **Analysis:** context (logs, events, metrics, traces) sanitized, then the LLM for production
  incidents; non-prod is tracked without it. It only reads the cluster - no Secrets, no writes.
- **Delivery:** one Slack message per incident (webhooks from its Secret); without them, its log.
- **Runs on kind too**, with your own LLM key (`docs/local-dev.md`).

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
│  ┌──────────────┐      ┌────────────────┐                 │
│  │   Grafana    │      │ k8s-ai-monitor │                 │
│  │              │      │                │                 │
│  │  - Dashboards│      │  - Triage      │                 │
│  │  - Explore   │      │  - Alert route │                 │
│  └──────────────┘      └────────────────┘                 │
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

### k8s-ai-monitor

**Local Access:** every route except `/healthz` needs the `internal-token` from the Guardian's Secret:
```bash
kubectl --context kind-sre-control-plane -n observability port-forward svc/k8s-ai-monitor 8080:8080
TOKEN=$(kubectl --context kind-sre-control-plane -n observability get secret k8s-ai-monitor-secrets \
  -o jsonpath='{.data.internal-token}' | base64 -d)
curl -s -H "X-Internal-Token: $TOKEN" http://localhost:8080/incidents
```

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

Principle: every alert names an action and has a reason for its urgency; at rest only `Watchdog` fires.
All backend rules are per namespace and count user requests only (not `/healthz`, `/readyz`, `/livez`,
`/metrics`). Configured alerts:

| Alert Name | Severity | Fires when | Action |
|------------|----------|------------|--------|
| `BackendErrorBudgetBurnFast` | critical | >7.2% of user requests fail over 1h and 5m (14.4x the 99.5% budget), min traffic | users are failing: check the last change and the error logs |
| `BackendErrorBudgetBurnSlow` | warning | >3% fail over 6h and 30m (6x), min traffic | plan the fix before the budget is gone |
| `BackendNoReadyPods` | critical | no available backend replica for 2m | restore the service: read the pod status |
| `BackendLatencyHigh` | warning | user p95 >1s for 10m, min traffic | find the slow route, then its trace |
| `BackendNearMemoryLimit` | warning | working set >90% of the limit for 15m | a leak or a size - before OOMKilled (Chapter 08) |

Left to the default rules: lost scrapes (`TargetDown`), restarting pods (`KubePodCrashLooping`).
Disabled in `kube-prometheus-stack/base/release.yaml`: scraping and rules for etcd, scheduler,
controller manager and kube-proxy (neither kind nor k3s exposes them), and `KubeHpaMaxedOut`
(develop/staging run HPAs with min = max on purpose).

### Backup Alert Rules

**Files:** `kube-prometheus-stack/monitoring/backup-alerts.yaml` (rules) and `cnpg-podmonitor.yaml`
(scrapes the app-postgres instances on port 9187; the NetworkPolicy
`network-policies/base/allow-postgres-metrics-from-observability.yaml` lets Prometheus in).

| Alert Name | Severity | Fires when | Action |
|------------|----------|------------|--------|
| `PostgresWALArchivingFailing` | warning | the newest WAL segment failed to archive, for 15m | point-in-time restore stops at the last good segment: check the backup store's credentials, endpoint, network policy |
| `PostgresBackupFailed` | warning | the newest base backup failed after the last good one, for 5m | read the failed Backup's `status.error`, fix, take a new backup |
| `PostgresBackupTooOld` | warning | no completed base backup for 26h (daily schedule + 2h), still true 15m later | check the ScheduledBackup, take a backup by hand |
| `PostgresNeverBackedUp` | warning | the instance has run 26h and has no completed base backup at all, still true 15m later | the ScheduledBackup is missing or suspended: take a backup by hand |

Left out on purpose: the age of the last archived WAL segment. An idle database writes no WAL, so
nothing is archived for hours - that alert would fire on every quiet cluster. The failure itself is the
signal: the last attempt is newer than the last success.

### Alert Routing Path

- Prometheus rules define detection logic and severity; Alertmanager routes and groups
  (`alerting/routing/routing.yaml`, on kind and on the platform):
  - `production` alerts and any other critical alert -> receiver `production`
  - `develop`/`staging` alerts and any other warning -> receiver `nonprod`
  - one notification per environment and alert name; a critical backend alert mutes the backend
    warnings of the same environment
- On the platform the two receivers post to Slack (`alerting/slack-receivers.yaml`, enabled once
  the SOPS Secret `alertmanager-slack` exists). On kind they have no integration; the Alertmanager API
  shows where each alert group went.
- `Watchdog` goes to Healthchecks.io as a heartbeat (`alerting/watchdog-heartbeat.yaml`, platform only).
- Chapter 14: a second AlertmanagerConfig (`k8s-ai-monitor/alertmanager-guardian.yaml`) hands every
  alert to the Guardian, which posts one message per incident. It lives with the Guardian, so where the
  Guardian does not run, nothing points at it.

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
kubectl get kustomization -n flux-system observability observability-resources k8s-ai-monitor

# Check HelmRelease
kubectl get helmrelease -n observability

# Check all pods
kubectl get pods -n observability

# Check Prometheus targets
kubectl port-forward -n observability svc/kube-prometheus-stack-prometheus 9090:9090
# Then visit: http://localhost:9090/targets
```

### k8s-ai-monitor Secrets

1. Copy and encrypt the example secret:
```bash
cp flux/secrets/observability/k8s-ai-monitor-secrets.yaml.example \
   flux/secrets/observability/k8s-ai-monitor-secrets.yaml
sops flux/secrets/observability/k8s-ai-monitor-secrets.yaml
```
2. Uncomment `k8s-ai-monitor-secrets.yaml` in `flux/secrets/observability/kustomization.yaml`.
3. Reconcile:
```bash
flux reconcile kustomization secrets-observability -n flux-system --with-source
flux reconcile kustomization k8s-ai-monitor -n flux-system --with-source
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

3. Check k8s-ai-monitor pipeline:
```bash
kubectl -n observability logs deploy/k8s-ai-monitor --tail=200
kubectl port-forward -n observability svc/k8s-ai-monitor 8080:8080
# curl -H "X-Internal-Token: $TOKEN" http://localhost:8080/state   (token: see "Local Access")
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
   - Enable authentication for Prometheus and Grafana endpoints
   - Use TLS for ingress

2. **High Availability:**
   - Run multiple Prometheus replicas
   - Use Thanos for long-term storage
   - Define `k8s-ai-monitor` HA/backup strategy before scaling replicas

3. **Resource Limits:**
   - Adjust resource requests/limits based on actual usage
   - Monitor Prometheus memory usage (can grow with cardinality)

4. **Alerting:**
   - Configure `k8s-ai-monitor` webhook destination (OpsGenie relay/integration)
   - Set up escalation policies
   - Test end-to-end alert routing regularly

5. **Retention:**
   - Adjust retention based on compliance requirements
   - Consider long-term storage with Thanos or Cortex

## Resources

- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [Kube-Prometheus-Stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Documentation](https://grafana.com/docs/)

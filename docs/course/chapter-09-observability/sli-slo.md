# SLI/SLO Spec: Chapter 09 Baseline

## Scope

Service in scope:
- `backend` HTTP API

Environment scope:
- `develop`, `staging`, `production`

## Indicators (SLIs)

1. Availability SLI
- Definition: ratio of successful requests (non-5xx) to total requests.
- PromQL:

```promql
1 - (
  sum(rate(app_http_requests_total{job="backend",status=~"5.."}[30m]))
  /
  clamp_min(sum(rate(app_http_requests_total{job="backend"}[30m])), 1e-9)
)
```

2. Latency SLI (p95)
- Definition: p95 backend request duration over rolling window.
- PromQL:

```promql
histogram_quantile(0.95,
  sum(rate(app_http_request_duration_seconds_bucket{job="backend"}[5m])) by (le)
)
```

## Objectives (SLOs)

1. Availability SLO
- Target: `99.5%` over 30 days.
- Error budget: `0.5%`.

2. Latency objective (operational target)
- Target: `p95 < 1s` on 5-minute windows.
- Used for warning/critical operational alerts.

## Alert Strategy

1. Immediate symptom alerts
- `BackendCriticalErrorRate`
- `BackendHighLatency`
- `BackendServiceDown`

2. Budget consumption alerts (burn-rate)
- `BackendSLOErrorBudgetBurnCritical`:
  fast burn on 5m and 1h windows (14.4x budget).
- `BackendSLOErrorBudgetBurnWarning`:
  sustained burn on 30m and 1h windows (6x budget).

## Guardrails

- Do not page only on single-point spikes without cross-signal evidence.
- For customer-impact decisions, require:
  metrics symptom + one representative trace + correlated log line.
- Every alert route must include runbook:
  `runbook-incident-debug.md`.

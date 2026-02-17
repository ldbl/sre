# Runbook: Incident Debug (Metrics -> Traces -> Logs)

## Purpose

Provide one repeatable on-call path for the most common symptom:
- elevated latency and/or sporadic 5xx

This runbook is optimized for the current MVP setup:
- direct export to Uptrace from frontend/backend
- no in-cluster OTel collector

## Inputs

- environment (`develop`, `staging`, or `production`)
- incident window (UTC time range)
- primary route/symptom if known

## Step 1: Confirm Symptom (Metrics First)

Check service-level symptoms:
- request rate anomaly
- p95/p99 latency increase
- 5xx error-rate increase

Decision:
- if no metric deviation, treat as likely client/local issue and continue with scoped tracing
- if deviation exists, continue to traces

PromQL shortcuts:

```promql
# Error rate (5m)
sum(rate(app_http_requests_total{job="backend",status=~"5.."}[5m]))
/ clamp_min(sum(rate(app_http_requests_total{job="backend"}[5m])), 1e-9)

# Latency p95 (5m)
histogram_quantile(0.95,
  sum(rate(app_http_request_duration_seconds_bucket{job="backend"}[5m])) by (le)
)
```

## Step 2: Pivot to Traces

In Uptrace, filter by:
- `service.name = "backend"` (and `frontend` when needed)
- time range around the spike
- status/error indicators

Find one representative failing or slow trace and capture:
- `trace_id`
- top slow span
- endpoint/route attributes

## Step 3: Correlate Logs by trace_id

Kubernetes log check:

```bash
kubectl -n <env> logs deploy/backend --since=30m | rg "<trace_id>"
```

For crash scenario (`/panic`):

```bash
kubectl -n <env> logs deploy/backend --since=30m | rg "panic|trace_id"
```

Expected:
- one or more backend entries with the same `trace_id`
- clear error context (panic, timeout, dependency issue, etc.)

## Step 4: Classify and Decide

Class A: isolated or low impact
- monitor + create follow-up issue

Class B: recurring but controlled impact
- apply low-risk mitigation and monitor

Class C: active customer impact
- execute rollback/fix path per service runbook
- communicate incident status update immediately

## Step 4.1: Validate Alert Context

Check whether one of these alerts is active for the same window:
- `BackendHighErrorRate` / `BackendCriticalErrorRate`
- `BackendHighLatency`
- `BackendSLOErrorBudgetBurnCritical` / `BackendSLOErrorBudgetBurnWarning`

If no matching alert exists but traces/logs confirm impact:
- classify as detection gap
- open follow-up issue for alert tuning (threshold/window/labels)

## Step 5: Verify Recovery

After mitigation:
- confirm latency and error metrics recover
- confirm new traces return to normal duration/status
- confirm no repeating error logs for same pattern

## Frontend -> Backend Crash Drill

1. Trigger panic from frontend Chaos page.
2. Capture returned `trace_id`.
3. In Uptrace, open trace and verify frontend + backend spans share the same trace.
4. In backend logs, filter by that `trace_id`.
5. Confirm panic event and restart behavior are visible.

## Database Leg (When Added)

Current status:
- DB spans are not yet implemented in baseline app path.

When DB layer is introduced, extend this runbook:
- require DB child span under backend request span
- require DB error/latency evidence before rollback decision
- include slow-query fingerprint in incident notes

## Evidence Template

- Environment:
- Time window:
- Symptom metric(s):
- `trace_id`:
- Correlated log evidence:
- Impact class (A/B/C):
- Action taken:
- Verification result:
- Alert observed (name + state):

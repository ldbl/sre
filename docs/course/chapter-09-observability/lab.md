# Lab: Baseline Observability with Uptrace (No In-Cluster Collector)

## Goal

Validate that telemetry is operational and correlated:
- frontend creates spans for user actions
- backend receives trace context and emits correlated logs
- Uptrace shows trace chain and related service signals
- Prometheus alert path is connected to the same incident workflow

## Prerequisites

- frontend and backend are deployed in one environment (recommended: `develop`)
- Uptrace DSN is configured in secrets and injected into workloads
- Flux reconciliation is healthy

Quick checks:

```bash
kubectl -n flux-system get kustomizations
kubectl -n develop get deploy frontend backend
kubectl -n develop get secret backend-secrets
kubectl -n observability get prometheusrule backend-alerts backend-slo-rules
```

## Step 1: Verify Runtime Telemetry Config

```bash
kubectl -n develop get deploy frontend -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="VITE_UPTRACE_DSN")].name}{"\n"}'
kubectl -n develop get deploy backend -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="UPTRACE_DSN")].name}{"\n"}'
```

Expected:
- frontend has `VITE_UPTRACE_DSN`
- backend has `UPTRACE_DSN`

## Step 2: Generate Trace via Frontend

1. Open frontend UI.
2. Go to Chaos page.
3. Trigger one action:
- delay or status action for non-destructive check
- panic action for crash/correlation drill

Expected:
- frontend creates manual span (for example `ui.chaos.trigger_panic`)
- backend receives request with propagated trace context

## Step 3: Verify in Uptrace

In Uptrace, find the trace from the recent action and confirm:
- frontend span exists
- backend HTTP span is a child in the same trace
- status/error details are visible on backend span

## Step 4: Verify Correlated Backend Logs

Get recent backend logs:

```bash
kubectl -n develop logs deploy/backend --tail=200
```

Expected:
- request/error logs contain `trace_id`
- for panic flow, log contains panic termination message with same `trace_id`

## Step 5: Capture Evidence

For lab completion, attach:
- one Uptrace trace screenshot/id
- one backend log snippet with matching `trace_id`
- one alert snapshot (`BackendHighLatency` or one SLO burn-rate alert state)
- one short conclusion (root cause + next action)

## Step 6: Optional Alert Drill (Recommended)

1. Trigger `/status/500` repeatedly from Chaos page for 5-10 minutes.
2. In Prometheus Alerts UI, verify one error-rate alert enters `pending` or `firing`.
3. Pivot to Uptrace trace + backend log evidence before deciding action.

## Hard Stop Conditions

- telemetry secrets missing or plaintext in Git
- no trace context propagation (orphan backend spans only)
- on-call action chosen without evidence from at least two signals

## Failure Scenarios

1. No traces in Uptrace
- verify DSN wiring in frontend/backend env
- verify app can reach Uptrace endpoint

2. Backend spans exist but not linked to frontend spans
- verify propagation headers are allowed by CORS (`traceparent`, `tracestate`, `baggage`)
- verify frontend instrumentation is enabled

3. Logs exist but no `trace_id`
- verify request logging path and panic handler logging
- verify request executed via instrumented routes

## Done When

- learner can produce one correlated incident sample (trace + log by `trace_id`)
- learner can explain the chosen action based on evidence
- learner can identify whether issue is config, propagation, or runtime behavior
- learner can identify at least one matching alert for the same symptom

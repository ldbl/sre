# Chapter 09: Observability (Metrics, Logs, Traces)

## Why This Chapter Exists

Without correlated signals, incidents become guesswork.
This chapter defines the minimum production baseline:
- metrics for symptom detection
- traces for path analysis
- logs for evidence

## Scope Decision (MVP)

- No in-cluster OpenTelemetry Collector in this phase.
- Frontend and backend export telemetry directly to Uptrace.
- Target investigation path: `frontend -> backend` now, `-> database` when DB layer is introduced.

References:
- `docs/observability/uptrace-cloud.md`
- `docs/observability/uptrace-e2e-plan.md`

## The Incident Hook

Users report intermittent 5xx errors and slow responses.
Dashboards show elevated latency, but root cause is unclear.
Without trace correlation, the team jumps between pods/logs blindly.
With baseline observability, on-call narrows cause in minutes.

## Guardrails

- No telemetry credentials in plaintext Git.
- No debugging based on logs-only; always pivot through traces.
- Keep rollback decision tied to evidence: metrics + traces + logs.

## Repo Mapping

- Frontend telemetry init: `../frontend/src/services/telemetry.js`
- Frontend manual spans: `../frontend/src/stores/backend.js`, `../frontend/src/views/ChaosView.vue`
- Backend telemetry: `../backend/pkg/telemetry/telemetry.go`
- Backend trace/log correlation and panic endpoint: `../backend/pkg/server/server.go`
- Kubernetes env wiring: `flux/apps/frontend/base/deployment.yaml`, `flux/apps/backend/base/deployment.yaml`

## Lab Files

- `lab.md`
- `runbook-incident-debug.md`
- `sli-slo.md`
- `quiz.md`

## Done When

- learner can trigger and find one end-to-end trace from frontend to backend
- learner can match backend error log by `trace_id`
- learner can run incident workflow `metrics -> traces -> logs -> action`
- learner can explain backend availability SLI/SLO and validate burn-rate alerts

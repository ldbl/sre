# Lab: Controlled Chaos with Safety Guardrails

## Goal

Run one deterministic failure drill and one Chaos Monkey drill in `develop`:
- confirm detection
- run incident workflow
- verify recovery

## Prerequisites

```bash
kubectl -n flux-system get kustomization chaos-monkey-develop
kubectl -n develop get deploy frontend backend
kubectl -n observability get prometheusrule backend-alerts backend-slo-rules
```

## Step 1: Deterministic Drill (Backend 5xx)

Generate controlled 5xx from frontend Chaos page or directly:

```bash
kubectl -n develop port-forward svc/backend 8080:8080
for i in $(seq 1 40); do curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/status/500; done
```

Expected:
- error-rate metric spike
- related backend traces/logs

## Step 2: Chaos Monkey Enable (Short Window)

Enable monkey for one run:

```bash
kubectl -n flux-system patch cronjob chaos-monkey --type merge -p '{"spec":{"suspend":false}}'
kubectl -n flux-system create job --from=cronjob/chaos-monkey chaos-monkey-manual-1
kubectl -n flux-system logs job/chaos-monkey-manual-1
```

Expected log event shape:
- `event=chaos_monkey_delete_pod`
- target namespace `develop`
- target app `frontend` or `backend`

Disable again:

```bash
kubectl -n flux-system patch cronjob chaos-monkey --type merge -p '{"spec":{"suspend":true}}'
```

## Step 3: Incident Flow

For the monkey action window, collect:
- one metric symptom (availability/latency/restarts)
- one Uptrace trace id
- one backend log line with same `trace_id` (when backend path impacted)

## Step 4: Recovery Verification

```bash
kubectl -n develop get pods -l app=backend
kubectl -n develop get pods -l app=frontend
kubectl -n develop get deploy backend frontend
```

Confirm:
- desired replicas restored
- no persistent error spike after stabilization window

## Step 5: Scorecard

Complete `scorecard.md` with:
- MTTD
- MTTR
- signal quality
- one hardening action

## Hard Stop Conditions

- chaos monkey left enabled outside approved exercise window
- monkey targeting namespaces other than `develop`
- action taken without trace/log evidence

## Done When

- one deterministic and one monkey drill completed
- recovery confirmed
- scorecard captured with follow-up action

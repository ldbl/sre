# Lab: Guardian on Top of Controlled Chaos (Draft)

## Goal

Validate guardian flow end-to-end for one controlled incident:
- detect from cluster events/scanner
- structured AI analysis
- incident persistence and lifecycle actions

## Prerequisites

- Chapter 11 chaos flow available in `develop`
- `k8s-ai-monitor` image built and deployed in playground cluster
- `STATE_BACKEND=sqlite`
- API token configured for write endpoints

## Step 1: Trigger Controlled Failure

Use one scenario:
- `backend /status/500` burst, or
- `backend /panic`, or
- one manual Chaos Monkey run.

Capture start timestamp.

## Step 2: Verify Detection

Check guardian logs:

```bash
kubectl -n <guardian-ns> logs deploy/k8s-ai-monitor --since=15m
```

Expected:
- warning/scan detection
- state key creation
- analysis call entry

## Step 3: Verify Incident Record

```bash
kubectl -n <guardian-ns> port-forward deploy/k8s-ai-monitor 8080:8080
curl -s http://localhost:8080/incidents | jq
```

Expected:
- active incident present
- `occurrence_count >= 1`

## Step 4: Validate Structured Analysis

```bash
curl -s http://localhost:8080/incidents/<id> | jq
```

Expected fields:
- `root_cause`
- `confidence`
- `hypotheses[]`
- `suggested_actions[]`

## Step 5: Incident Lifecycle Actions

```bash
curl -s -X POST -H "X-Internal-Token: <token>" http://localhost:8080/incidents/<id>/ack
curl -s -X POST -H "X-Internal-Token: <token>" http://localhost:8080/incidents/<id>/resolve
```

Expected:
- status transitions to `acknowledged`, then `resolved`

## Step 6: Cost/Usage Check

```bash
curl -s "http://localhost:8080/llm-usage?hours=24" | jq
```

Confirm:
- calls are rate-limited
- usage and cost visible for audit

## Hard Stop Conditions

- guardian attempts autonomous remediation
- raw secrets/tokens visible in incident context
- no dedup and alert storm on repeated identical events

## Done When

- one chaos incident is fully tracked by guardian
- analysis is structured and actionable
- lifecycle actions are auditable

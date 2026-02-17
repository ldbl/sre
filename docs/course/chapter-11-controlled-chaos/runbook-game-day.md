# Runbook: Controlled Chaos Game Day

## Purpose

Run controlled failure injection with strict safety boundaries and evidence-based response.

## Roles

- Incident Commander: owns decision flow
- Driver: executes injection commands
- Observer: records timeline and evidence

## Preflight (Required)

1. Confirm environment is `develop`.
2. Confirm rollback path is known.
3. Confirm monitoring/tracing access is available.
4. Confirm Chaos Monkey is `suspend: true` before and after run.

## Timeline Template

1. T0: baseline metrics snapshot
2. T+2m: inject failure
3. T+5m: detect symptom
4. T+10m: isolate via traces/logs
5. T+15m: mitigate/recover
6. T+25m: verify stability
7. T+35m: write scorecard + actions

## Injection Options

1. Deterministic:
- `GET /status/500`
- `GET /panic`

2. Monkey:
- one pod deletion via `chaos-monkey` job

## Decision Classes

- Class A: low impact, recover automatically
- Class B: moderate impact, manual mitigation needed
- Class C: customer-impact pattern, trigger rollback/incident protocol

## Exit Criteria

- service recovered to baseline
- no active critical alerts for drill scenario
- evidence package complete (metrics + traces + logs)
- at least one hardening issue created

## Post-Run Deliverables

- filled `scorecard.md`
- one short blameless summary
- one backlog item with owner and due date

# Runbook: Linkerd Progressive Delivery Operations (Advanced)

## Purpose

Operate canary and A/B rollouts with objective safety gates.

## Pre-Rollout Checklist

1. Linkerd control plane healthy (`linkerd check`).
2. Target workload meshed and observable.
3. Abort thresholds defined and approved.
4. Rollback action documented and tested.

## Canary Operation Flow

1. Start canary at low traffic weight.
2. Evaluate window metrics (success rate, latency, error rate).
3. Promote only if all thresholds pass.
4. Abort automatically or manually on threshold breach.
5. Record decision with evidence.

## A/B Operation Flow

1. Define experiment hypothesis and metric target.
2. Apply bounded route split (header/cookie/segment).
3. Run for fixed window.
4. Compare cohorts and decide keep/revert.
5. Remove temporary routing rules after decision.

## Commands (Examples)

```bash
linkerd check
linkerd -n develop stat deploy
linkerd -n develop routes deploy/<app-name>
kubectl -n develop get canary
kubectl -n develop describe canary <app-name>
```

## Failure Modes

1. Metric noise causes false abort:
- increase observation window; validate baseline first

2. Canary stuck:
- inspect controller events and policy spec; rollback if uncertain

3. A/B drift:
- ensure route selectors are explicit and temporary rules are removed

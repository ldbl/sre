# Runbook: Rollback and Migration Operations (Advanced)

## Purpose

Operate application + schema releases with explicit rollback safety and minimal blast radius.

## Scope

This runbook covers:
- migration classification and sequencing
- rollback execution order
- incident handling for migration-related failures
- destructive migration approval gates

## Migration Types

1. Expand (safe/additive):
- add nullable columns
- add new tables/indexes
- keep old schema path valid

2. Contract (destructive):
- drop/rename columns
- remove legacy constraints/paths
- only after stable compatibility window

## Pre-Deploy Checklist

1. Migration classified (`expand` or `contract`).
2. Rollback window defined with owner and duration.
3. Backup/restore evidence is fresh.
4. Feature flag plan exists for new code path.
5. Monitoring and alert thresholds are confirmed.

## Rollout Sequence (Mandatory)

1. Expand migration.
2. Application deploy with flag OFF.
3. Controlled flag enable.
4. Observe stability window.
5. Contract migration (approval required).

## Rollback Order

If incident occurs after expand + app deploy:
1. disable feature flag (fastest mitigation)
2. rollback application version if needed
3. keep expanded schema intact
4. investigate before any schema reversal

If destructive migration already applied:
1. treat as high-severity incident
2. invoke restore/data recovery protocol
3. communicate RTO/RPO impact immediately

## Commands / Evidence

```bash
kubectl -n develop get pods
kubectl -n develop get events --sort-by=.lastTimestamp | tail -n 30
```

Add your migration tool commands and SQL evidence to incident timeline.

## Break-Glass Rules

Allowed only with:
- incident owner approval
- explicit risk acceptance
- documented rollback/recovery path
- post-incident follow-up task

## Failure Modes

1. Mixed-version incompatibility:
- symptom: old pods fail against new schema
- action: disable flag + rollback app, preserve expand schema

2. Long-running lock/contention migration:
- symptom: API latency spikes/timeouts
- action: stop rollout, reduce scope, schedule maintenance window

3. Data integrity regression:
- symptom: missing/corrupted values after migration
- action: incident protocol + restore/repair workflow

# Lab: Rollback-Safe Migration Drill (Advanced)

## Goal

Run a controlled migration rollout in non-production with explicit rollback points:
- apply additive schema migration
- deploy app-compatible change behind feature flag (simulated)
- validate rollback path
- define contract migration go/no-go decision

## Prerequisites

- access to `develop` namespace
- CNPG cluster available (or any PostgreSQL test target)
- backup/restore workflow familiarity from Chapter 10

Current-state note:
- if backend DB login flow is not implemented yet, run this as schema/process simulation
- keep the same sequence; replace simulated step with real app checks later

Quick checks:

```bash
kubectl -n develop get cluster.postgresql.cnpg.io
kubectl -n develop get pods
```

## Step 1: Define Migration Plan and Rollback Window

Document before execution:
- migration id and purpose
- additive vs destructive classification
- rollback window duration (for example 24h)
- rollback owner and approval path

Hard stop:
- no approved rollback window -> no migration rollout.

## Step 2: Apply Expand Migration (Additive Only)

Example SQL migration (table is demo only):

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_version INTEGER DEFAULT 1;
```

Execute via your migration tool/job and record execution evidence.

## Step 3: Simulate App Rollout with Feature Flag

Because backend DB flow is pending, simulate with release metadata:
- deploy new app version
- keep migration-dependent logic disabled (`FEATURE_LOGIN_V2=false`)
- verify baseline endpoints and health checks

When backend login is implemented, this step becomes real functional validation.

## Step 4: Enable Flag in Controlled Scope

Enable feature flag for small scope (develop first):
- monitor error rate, latency, and DB-related failures
- keep old code path available during rollback window

If SLO degrades:
- disable flag first
- keep additive schema (do not run destructive rollback)

## Step 5: Rollback Drill

Simulate failed rollout and execute rollback sequence:
1. rollback app version or disable feature flag
2. verify app health and user-path recovery
3. confirm old code still works with expanded schema

Capture:
- command history
- observed failure signal
- recovery time

## Step 6: Contract Migration Decision

Do not execute destructive migration in this drill by default.
Instead, produce go/no-go checklist for contract step (drop/rename):
- traffic fully on new code path
- rollback window passed without incidents
- backup/restore evidence is current
- explicit approval recorded

## Optional Cleanup

If simulation resources were created, remove them and keep migration notes attached to runbook evidence.

## Evidence to Capture

- migration plan document with rollback window
- expand migration execution output
- app/flag rollout logs and health checks
- rollback drill timeline and result
- contract migration go/no-go decision

## Hard Stop Conditions

- destructive schema change before compatibility window
- app and schema breaking changes in one unreviewed step
- migration run without tested backup/restore path

## Done When

- learner demonstrates rollback-safe sequence end-to-end
- learner can defend why contract migration must be delayed

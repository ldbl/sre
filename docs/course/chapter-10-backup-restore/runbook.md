# Runbook: Backup and Restore (CNPG)

## Purpose

Provide a repeatable procedure to:
- confirm backup health
- execute manual backup
- run restore simulation safely

## Scope

- primary target: `develop` or `staging`
- production restore only under incident protocol

## Step 1: Backup Health Check

```bash
kubectl -n <env> get cluster.postgresql.cnpg.io app-postgres
kubectl -n <env> get scheduledbackup
kubectl -n <env> get backup
```

If no recent successful backup:
- trigger manual backup immediately
- open incident/task for backup pipeline investigation

## Step 2: Manual Backup

```bash
cat <<EOF | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: app-postgres-manual-$(date +%Y%m%d%H%M%S)
  namespace: <env>
spec:
  cluster:
    name: app-postgres
EOF
```

Track:

```bash
kubectl -n <env> get backup -w
```

## Step 3: Restore Simulation

Create temporary restore cluster in same non-prod namespace.
Use same object-store credentials secret (`cnpg-backup-s3`) and source path.

Success criteria:
- restore cluster reaches ready state
- connectivity check succeeds
- optional data validation query succeeds

## Step 4: Decision

- If restore succeeds: mark backup chain healthy.
- If restore fails: escalate as backup incident (backup exists but unusable).

## Evidence to Record

- environment
- backup object name and completion time
- restore cluster name and readiness state
- connectivity/query validation output
- follow-up actions

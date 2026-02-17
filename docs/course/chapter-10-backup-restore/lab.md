# Lab: CloudNativePG Backup and Restore Simulation

## Goal

Run end-to-end backup basics in `develop`:
- verify CNPG cluster and scheduled backup
- trigger one on-demand backup
- perform restore simulation into a separate cluster

## Prerequisites

- CNPG operator is ready
- `app-postgres` exists in `develop`
- secret `cnpg-backup-s3` exists in `develop`

```bash
kubectl -n cnpg-system get pods
kubectl -n develop get cluster.postgresql.cnpg.io app-postgres
kubectl -n develop get secret cnpg-backup-s3
```

## Step 1: Verify Scheduled Backup

```bash
kubectl -n develop get scheduledbackup
kubectl -n develop describe scheduledbackup app-postgres-daily
```

Expected:
- schedule is present
- target cluster is `app-postgres`

## Step 2: Trigger Manual Backup

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: app-postgres-manual
  namespace: develop
spec:
  cluster:
    name: app-postgres
EOF
```

Track status:

```bash
kubectl -n develop get backup
kubectl -n develop describe backup app-postgres-manual
```

Expected:
- backup reaches completed state

## Step 3: Restore Simulation (Separate Cluster)

Apply restore cluster (non-prod simulation):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: app-postgres-restore
  namespace: develop
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:17
  storage:
    size: 10Gi
  externalClusters:
    - name: app-postgres-source
      barmanObjectStore:
        destinationPath: s3://sre-cnpg-backups/develop/app-postgres
        endpointURL: https://REPLACE_ME.r2.cloudflarestorage.com
        s3Credentials:
          accessKeyId:
            name: cnpg-backup-s3
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: cnpg-backup-s3
            key: ACCESS_SECRET_KEY
  bootstrap:
    recovery:
      source: app-postgres-source
EOF
```

Track restore:

```bash
kubectl -n develop get cluster.postgresql.cnpg.io app-postgres-restore -w
```

## Step 4: Validate Restored Cluster

```bash
kubectl -n develop get svc | rg app-postgres-restore
kubectl -n develop get pods -l cnpg.io/cluster=app-postgres-restore
```

Run a simple connectivity check:

```bash
kubectl -n develop run pg-check --rm -it --restart=Never --image=postgres:17 -- \
  sh -c 'pg_isready -h app-postgres-restore-rw -p 5432'
```

## Cleanup

```bash
kubectl -n develop delete backup app-postgres-manual --ignore-not-found=true
kubectl -n develop delete cluster.postgresql.cnpg.io app-postgres-restore --ignore-not-found=true
```

## Hard Stop Conditions

- backup credentials missing in namespace
- restore tested directly in production without staging/develop drill
- backup success claimed without recovery verification

## Done When

- learner demonstrates one completed manual backup
- learner demonstrates one restore simulation cluster
- learner captures evidence (status + connectivity result)

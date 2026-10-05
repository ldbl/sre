# CNPG clusters (app-postgres per environment)

One CloudNativePG cluster per environment (`develop`, `staging`, `production`), named `app-postgres`,
database and owner `app`, credentials in the Secret `app-postgres-app`.

## Backups

- **Continuous WAL archiving and a daily base backup** (`scheduled-backup.yaml`), with the in-tree
  `barmanObjectStore`, to `s3://${BACKUP_S3_BUCKET}/cnpg-backups/<namespace>/app-postgres`.
  Retention: 7 days.
- **Where:** MinIO inside the cluster on kind (bucket `sre`) - it does not survive the loss of the
  cluster; Hetzner Object Storage on the platform. The endpoint and bucket come from Terraform
  (ConfigMap substitution); the keys from the Secret `cnpg-backup-s3`.
- **Known tech debt:** CNPG 1.29 removes the in-tree `barmanObjectStore`. The operator chart is pinned
  (`cnpg-operator/release.yaml`) until the backups move to the Barman Cloud plugin.
- **Watched by** `PostgresWALArchivingFailing`, `PostgresBackupFailed` and `PostgresBackupTooOld`
  (`observability/kube-prometheus-stack/monitoring/backup-alerts.yaml`).

## Restore

A restore is a **new cluster next to the old one**, never an overwrite: `app-postgres-restore` in the
same namespace, bootstrapped from the base backup and the archived WAL - to the end of the archive,
or to a point in time before a bad change.

```bash
scripts/postgres-restore-manifest.sh -n develop -t 2026-10-05T09:30:00Z \
  | kubectl --context kind-sre-control-plane apply -f -
```

- The name `app-postgres-restore` is fixed: the NetworkPolicies (`network-policies/base`,
  `data/minio/network-policies.yaml`) allow it the same paths as `app-postgres` - the backup store, the
  API server, the operator, the backend. A restore under any other name hangs on a dropped connection.
- The script copies the image, storage and resources from the source and keeps the app's
  credentials, so the restored database can be checked with the application's own user.
- Proof of a restore is data, not `Ready`: the expected rows, read and written with the app user.
- Delete the restore cluster when done:
  `kubectl --context kind-sre-control-plane -n develop delete cluster.postgresql.cnpg.io app-postgres-restore`.

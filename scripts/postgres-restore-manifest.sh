#!/usr/bin/env bash
# postgres-restore-manifest.sh - print the CNPG Cluster that restores app-postgres side by side,
# as app-postgres-restore in the same namespace, from the backups in the object store.
#
# The restore never touches app-postgres: it is a new cluster, bootstrapped from the base backup
# and the archived WAL. Without -t it replays every archived segment; with -t it stops at that
# moment (point-in-time recovery) - before a bad change, for example.
#
# Usage:
#   scripts/postgres-restore-manifest.sh -n <namespace> [-c <context>] [-t <RFC 3339 time>]
#
# Examples:
#   scripts/postgres-restore-manifest.sh -n develop | kubectl --context kind-sre-control-plane apply -f -
#   scripts/postgres-restore-manifest.sh -n develop -t 2026-10-05T09:30:00Z > restore.yaml
#
# The cluster: -c, else $KUBE_CONTEXT, else kind-sre-control-plane. The script only reads there
# (the source Cluster and the backup Secret cnpg-backup-s3); it prints, you apply.
#
# (Lines 2-17 above are also the --help text: usage() prints them. Keep notes for readers below.)
# Run by hand from the runbook and the Chapter 12 lab. Needs: kubectl and jq.
# Why these fields:
#   - serverName: app-postgres - the archive lives under the SOURCE cluster's name; without it CNPG
#     looks under the external cluster's name and finds nothing.
#   - imageName, storage, resources copied from the source - a physical restore needs the same
#     Postgres major version, and the namespace quota has to fit it.
#   - database/owner/secret: the restored database keeps the app's credentials (app-postgres-app),
#     so the application can be pointed at it to prove the restore.
#   - The NetworkPolicies already allow the name app-postgres-restore (network-policies/base,
#     data/minio) - any other name hangs on a silently dropped connection to the backup store.
set -euo pipefail

NAMESPACE=""
TARGET_TIME=""
CONTEXT="${KUBE_CONTEXT:-kind-sre-control-plane}"
SOURCE="app-postgres"
RESTORE="app-postgres-restore"

# usage - print the header comment of this file (lines 2-17) as help, then exit 1.
usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n) NAMESPACE="$2"; shift 2 ;;
    -c) CONTEXT="$2"; shift 2 ;;
    -t) TARGET_TIME="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done
[ -n "$NAMESPACE" ] || { echo "-n <namespace> is required" >&2; usage; }
if [ -n "$TARGET_TIME" ] && ! [[ "$TARGET_TIME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$ ]]; then
  echo "-t must be an RFC 3339 time, e.g. 2026-10-05T09:30:00Z (got '$TARGET_TIME')" >&2; exit 2
fi

k() { kubectl --context "$CONTEXT" -n "$NAMESPACE" "$@"; }

source_json=$(k get cluster.postgresql.cnpg.io "$SOURCE" -o json) \
  || { echo "cannot read Cluster $SOURCE in $NAMESPACE ($CONTEXT)" >&2; exit 1; }
# b64 - one key of the backup Secret, decoded; fails loudly when the key is missing.
b64() { k get secret cnpg-backup-s3 -o "jsonpath={.data.$1}" | base64 -d; }
bucket=$(b64 BUCKET); endpoint=$(b64 ENDPOINT)
[ -n "$bucket" ] && [ -n "$endpoint" ] || { echo "cnpg-backup-s3 in $NAMESPACE has no BUCKET or ENDPOINT" >&2; exit 1; }

image=$(jq -r '.spec.imageName' <<<"$source_json")
size=$(jq -r '.spec.storage.size' <<<"$source_json")
resources=$(jq -c '.spec.resources // {}' <<<"$source_json")

target=""
[ -n "$TARGET_TIME" ] && target=$'\n'"      recoveryTarget:"$'\n'"        targetTime: \"$TARGET_TIME\""

cat <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: $RESTORE
  namespace: $NAMESPACE
spec:
  instances: 1
  imageName: $image
  storage:
    size: $size
  resources: $resources
  bootstrap:
    recovery:
      source: origin
      database: app
      owner: app
      secret:
        name: app-postgres-app$target
  externalClusters:
    - name: origin
      barmanObjectStore:
        serverName: $SOURCE
        destinationPath: s3://$bucket/cnpg-backups/$NAMESPACE/$SOURCE
        endpointURL: $endpoint
        s3Credentials:
          accessKeyId:
            name: cnpg-backup-s3
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: cnpg-backup-s3
            key: ACCESS_SECRET_KEY
EOF

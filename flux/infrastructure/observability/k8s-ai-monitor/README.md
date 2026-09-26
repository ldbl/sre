# k8s-ai-monitor (Observability Alert Router)

This module deploys `k8s-ai-monitor` in namespace `observability` as the primary alert routing path.

## What It Does

- Watches Kubernetes/Flux health signals.
- Pulls context from Kubernetes APIs and Prometheus.
- Performs AI-assisted incident triage.
- Sends notifications to a Slack-compatible webhook endpoint.

## OpsGenie Integration

`k8s-ai-monitor` currently posts through `SLACK_WEBHOOK_URL`.
For OpsGenie, point this value to:

- an OpsGenie Slack-compatible integration endpoint, or
- a webhook relay that forwards to OpsGenie Alerts API.

## Required Secret

Copy and encrypt:

- `flux/secrets/observability/k8s-ai-monitor-secrets.yaml.example`
  -> `flux/secrets/observability/k8s-ai-monitor-secrets.yaml`

Then uncomment this file in:

- `flux/secrets/observability/kustomization.yaml`

## Runtime Endpoints

- health: `GET /healthz`
- state: `GET /state`
- reports: `GET /reports`

Service name:

- `k8s-ai-monitor.observability.svc.cluster.local:8080`

## Access to Secrets

The monitor has **no** access to Secrets (`clusterrole.yaml`): a cluster-wide read would expose
`flux-system/sops-age`, the backup keys and every password to a component that processes alerts,
logs and LLM output. Its checks do not need Secret contents - Postgres services come from the backup
CronJob names, TLS state from the cert-manager `Certificate`, pull problems from the kubelet event.

The only exception is the opt-in S3 storage verification (`BACKUP_STORAGE_PROVIDER=s3`), which needs
the S3 credentials. Grant exactly that one Secret, in its namespace, and point the monitor at it:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: k8s-ai-monitor-s3-credentials, namespace: <ns> }
rules:
  - apiGroups: [""]
    resources: [secrets]
    resourceNames: [s3-backup-credentials]   # BACKUP_S3_SECRET_NAME
    verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: k8s-ai-monitor-s3-credentials, namespace: <ns> }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: Role, name: k8s-ai-monitor-s3-credentials }
subjects:
  - { kind: ServiceAccount, name: k8s-ai-monitor, namespace: observability }
```

and set `BACKUP_S3_SECRET_NAMESPACE=<ns>` (without it the monitor searches every watched namespace).


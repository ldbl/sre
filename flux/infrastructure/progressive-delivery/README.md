# Progressive Delivery (Traefik + Flagger)

This directory contains the GitOps manifests for progressive delivery:
- Flagger controller configured for the Traefik provider (`flagger/`)
- `develop` canaries for backend and frontend with MetricTemplates and IngressRoutes (`develop/`)

Both are enabled in `flux/bootstrap/flux-system/infrastructure.yaml` (Kustomizations `flagger` and
`progressive-delivery-develop`).

## Replicas and autoscaling

- The canaries use `autoscalerRef`: Flagger copies each app's HPA to `<app>-primary` (the Deployment
  that serves traffic) and keeps the canary Deployment at 0 between releases.
- Git sets no `spec.replicas` on the app Deployments: the HPA owns the count. See CLAUDE.md,
  "Resource Management", and `scripts/hpa-replicas-handover.sh` for existing clusters.

## Known gap: the analysis gets no traffic (2026-09-27)

The IngressRoutes match `Host(backend.develop.svc.cluster.local)` / `frontend...`, which nothing
sends, and the frontend nginx calls the backend Service directly (not through Traefik). With no
load tester, the `request-success-rate` query returns no values, the analysis halts 5 times and
Flagger rolls back: every new develop image is rejected and `<app>-primary` keeps the old one.
Tracked in the course plan (Ch19); fix before relying on develop releases.

## Prerequisites

1. Cluster observability stack is running (Prometheus endpoint available).
2. Traefik ingress controller is running (deployed via kube-hetzner).

## Check the develop canaries

- `kubectl -n develop get canary` - phase and weight
- `kubectl -n develop get traefikservice`
- `kubectl -n develop get hpa` - `backend-primary` / `frontend-primary` appear once Flagger has
  initialised the canaries with `autoscalerRef`

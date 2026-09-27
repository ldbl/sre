# Progressive Delivery (Traefik + Flagger)

This directory contains the GitOps manifests for progressive delivery (course Ch19):
- Flagger controller configured for the Traefik provider (`flagger/`) - always installed, idle
  without Canary objects
- `develop` canaries for backend and frontend with MetricTemplates and IngressRoutes (`develop/`) -
  **opt-in**: the Flux Kustomization is `flux/bootstrap/flux-system/progressive-delivery-develop.yaml`,
  which is not listed in that directory's `kustomization.yaml`

Until the canaries are enabled, develop gets a plain rolling update from the app Kustomizations.

## Enable (Ch19)

1. Make sure the analysis gets traffic (see "Known gap" below) - otherwise every release is rolled back.
2. Add `- progressive-delivery-develop.yaml` to the resources in
   `flux/bootstrap/flux-system/kustomization.yaml` and push.
3. Check: `kubectl -n develop get canary` (phase `Initialized`), `kubectl -n develop get hpa`
   (`backend-primary`, `frontend-primary`), `kubectl -n develop get traefikservice`.

## Disable

Remove the line again and push. The Canaries set `revertOnDeletion: true`: when Flux deletes them,
Flagger scales the app Deployment back up, points the Service at it again and removes its primary
objects. Without it the Service keeps selecting the deleted primary and the Deployment can stay at
0 replicas (an HPA does not scale up from 0). Tested on kind 2026-09-27: before deletion
`backend` had 0 replicas and the Service selected `backend-primary`; after it, 1 replica,
selector `app=backend`, `/api/healthz` 200.

## Replicas and autoscaling

- The canaries use `autoscalerRef`: Flagger copies each app's HPA to `<app>-primary` (the Deployment
  that serves traffic) and keeps the canary Deployment at 0 between releases.
- Git sets no `spec.replicas` on the app Deployments: the HPA owns the count. See CLAUDE.md,
  "Resource Management", and `scripts/hpa-replicas-handover.sh` for existing clusters.

## Known gap: the analysis gets no traffic (2026-09-27)

The IngressRoutes match `Host(backend.develop.svc.cluster.local)` / `frontend...`, which nothing
sends, and the frontend nginx calls the backend Service directly (not through Traefik). With no
load tester the `request-success-rate` query returns no values, the analysis halts 5 times and
Flagger rolls back: every new develop image was rejected and `<app>-primary` kept the old one
(on kind develop served a March build). This is why the canaries are opt-in; Ch19 adds the traffic.

## Prerequisites

1. Cluster observability stack is running (Prometheus endpoint available).
2. Traefik ingress controller is running (deployed via kube-hetzner).

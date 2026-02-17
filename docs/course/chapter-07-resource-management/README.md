# Chapter 07: Resource Management & QoS

## Why This Chapter Exists

Unbounded workloads create noisy-neighbor incidents and unpredictable recovery.
This chapter enforces resource discipline:
- requests/limits per container
- namespace quotas
- predictable QoS behavior under pressure

## Guardrails

- Every workload must define CPU/memory requests and limits.
- Namespaces must enforce `LimitRange` and `ResourceQuota`.
- OOM and throttling analysis must happen before scaling decisions.

## Repo Mapping

- App resources:
  - `flux/apps/backend/base/deployment.yaml`
  - `flux/apps/frontend/base/deployment.yaml`
- Namespace quotas/limits:
  - `flux/infrastructure/resource-management/develop/`
  - `flux/infrastructure/resource-management/staging/`
  - `flux/infrastructure/resource-management/production/`
- Flux wiring:
  - `flux/bootstrap/flux-system/infrastructure.yaml`
  - `flux/bootstrap/flux-system/apps.yaml`

## Current Implementation (This Repo)

- Backend and frontend define CPU/memory/ephemeral-storage requests+limits.
- `develop`, `staging`, `production` have `LimitRange` and `ResourceQuota` via Flux.
- Apps depend on resource-management Kustomizations before reconcile.

## Lab Files

- `lab.md`
- `quiz.md`

## Done When

- learner can explain Burstable vs Guaranteed vs BestEffort with real manifests
- learner can verify quota/limitrange enforcement in cluster
- learner can diagnose OOM/resource pressure from pod events and metrics

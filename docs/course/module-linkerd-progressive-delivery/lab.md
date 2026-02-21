# Lab: Linkerd Canary Rollout and A/B Routing (Advanced)

## Goal

Run one progressive delivery exercise in `develop`:
- validate Linkerd health and mTLS
- execute canary rollout with automated analysis
- run one A/B route experiment and review outcomes

## Prerequisites

- Linkerd control plane installed and healthy
- rollout controller installed (Flagger recommended)
- test workload and service available in `develop`
- baseline SLO signals available (Prometheus metrics)
- progressive-delivery manifests present in:
  - `flux/infrastructure/progressive-delivery/linkerd/`
  - `flux/infrastructure/progressive-delivery/flagger/`
  - `flux/infrastructure/progressive-delivery/develop/`

Quick checks:

```bash
linkerd check
kubectl -n linkerd get pods
kubectl -n develop get deploy,svc
```

## Step 1: Verify Mesh Baseline

Confirm workload is meshed and identities are present:

```bash
linkerd -n develop stat deploy
linkerd -n develop routes deploy/<app-name>
```

Expected:
- meshed workload metrics available
- request success/latency visible

## Step 2: Configure Canary Policy

Apply canary specs from this repo:
- step weights (example: 5, 25, 50, 100)
- analysis interval
- rollback/abort threshold (error rate, p95 latency)

```bash
kubectl -n develop apply -f flux/infrastructure/progressive-delivery/develop/canary-backend.yaml
```

## Step 3: Trigger New Version Rollout

Update image/version for canary target:

```bash
kubectl -n develop set image deploy/<app-name> <container>=<new-image>
```

Track progress:

```bash
kubectl -n develop get canary
kubectl -n develop describe canary <app-name>
```

## Step 4: Validate Automated Decision

Expected outcomes:
- promote to 100% when SLO passes, or
- auto-abort and rollback when thresholds fail

Capture evidence from:
- canary events/status
- Linkerd metrics (`stat`, `routes`)
- controller logs

## Step 5: A/B Routing Drill

Apply A/B canary policy based on header/cookie match in `develop` only.

```bash
kubectl -n develop apply -f flux/infrastructure/progressive-delivery/develop/canary-frontend.yaml
```

Validate both paths with test requests and compare key metrics.

## Hard Stop Conditions

- canary directly in production without non-prod rehearsal
- no explicit abort criteria
- A/B experiment without clear start/end and owner

## Done When

- learner demonstrates one canary decision path (promote or abort)
- learner demonstrates one A/B split with measurable result

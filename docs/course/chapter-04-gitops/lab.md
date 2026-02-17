# Lab: Version Promotion and Rollback with Flux GitOps

## Goal

Validate the real promotion model:
- `develop` and `staging` auto-update from env-specific tags
- `production` updates only from explicit promotion tags
- rollback is performed through Git (preferred path)

## Prerequisites

- Flux is installed and reconciling this repository
- namespaces exist: `develop`, `staging`, `production`
- access to service CI workflows (backend/frontend repos) for promotion trigger

## Step 1: Baseline Verification

```bash
flux get kustomizations -n flux-system
flux get images all -A

kubectl -n develop get deploy backend -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n staging get deploy backend -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n production get deploy backend -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Expected:
- `apps-develop`, `apps-staging`, `apps-production` are ready
- image tags match environment policy (`develop-*`, `staging-*`, `production-*`)

## Step 2: Verify Policy Guardrails

Confirm `ImagePolicy` regex per environment:
- develop: `^develop-v...-(?P<ts>...)$`
- staging: `^staging-v...-(?P<ts>...)$`
- production: `^production-v...-(?P<ts>...)$`

Reference paths:
- `flux/apps/backend/develop/image-policy.yaml`
- `flux/apps/backend/staging/image-policy.yaml`
- `flux/apps/backend/production/image-policy.yaml`

Hard stop conditions:
- production policy accepts non-`production-*` tags
- mutable `latest` appears in production manifests

## Step 3: Execute Promotion (Service Repo)

From service repo (backend or frontend), run manual promotion workflow:
- workflow: `promote-production.yml`
- source image: selected `staging-*` tag
- target tags: `production` and `production-v...`

Expected:
- GHCR contains new `production-v...` tag
- release metadata/version bump is recorded by the workflow

## Step 4: Verify Flux Applied Production Tag

```bash
flux get images all -A
kubectl -n production get deploy backend -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Expected:
- production deployment now points to the promoted `production-v...` tag
- change is traceable in Git history via Flux write-back commit

## Step 5: GitOps-First Rollback Drill

1. Identify Flux bot commit that introduced the latest production image tag.
2. Revert that commit in Git.
3. Wait for Flux reconcile, then verify production image is rolled back.

Verification:

```bash
flux reconcile source git flux-system
flux reconcile kustomization apps-production -n flux-system
kubectl -n production get deploy backend -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

## Failure Scenarios

1. Production did not update after promotion
- check `ImagePolicy` regex and `ImageRepository` scan results
- check image automation controller logs

2. Promotion updated wrong environment
- check namespace-scoped automation objects and target path
- verify Flux write-back commit path in Git

3. Emergency `rollout undo` was used
- treat as temporary mitigation
- reconcile Git state immediately to remove drift

## Done When

- learner proves artifact lineage from `staging-*` to `production-*`
- learner can show one successful production promotion and one Git-based rollback
- learner can explain why rebuild-for-production is disallowed

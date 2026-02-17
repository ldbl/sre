# Chapter 04: GitOps & Version Promotion

## Why This Chapter Exists

Production safety depends on controlled promotion, not ad-hoc rebuilds.
This chapter defines one deployment model:
- `develop` deploys `develop-*` images
- `staging` deploys `staging-*` images
- `production` deploys `production-*` images from explicit promotion

## The Incident Hook

A team rebuilds "the same" code for production during incident pressure.
The binary differs from staging due to dependency drift and build-time variance.
Rollback is confusing because the promoted artifact is not the one that was tested.
Time is lost proving artifact lineage instead of restoring service.

## What AI Would Propose (Brave Junior)

- "Just rebuild from main and deploy to production now."
- "Use mutable `latest` tag for speed."

Why this sounds reasonable:
- fast and simple under pressure
- fewer manual steps

## Why This Is Dangerous

- Rebuild breaks artifact immutability.
- Mutable tags destroy auditability.
- Incident response becomes guesswork across envs.

## Guardrails That Stop It

- Promotion without rebuild: `staging-*` is retagged to `production-*`.
- Immutable env/version tags are required.
- Flux image automation writes all image updates to Git.
- GitOps-first rollback via commit revert.

## Repo Mapping

- `docs/gitops-workflow.md`
- `flux/bootstrap/infrastructure/image-automation/`
- `flux/apps/backend/develop/`, `flux/apps/backend/staging/`, `flux/apps/backend/production/`
- `flux/apps/frontend/overlays/develop/`, `flux/apps/frontend/overlays/staging/`, `flux/apps/frontend/overlays/production/`

## Current Model (As Implemented)

1. Build on service `develop` branch pushes `develop-*` image tags.
2. Build on service `main` branch pushes `staging-*` image tags.
3. Manual promotion workflow retags selected `staging-*` image to:
- `production`
- `production-v<major>.<minor>.<patch>-<short_sha>-<unix_ts>`
4. Flux `ImagePolicy` selects latest env-matching immutable tag.
5. Flux `ImageUpdateAutomation` commits updated tags to Git and reconciles.

## Lab Files

- `lab.md`
- `quiz.md`

## Done When

- learner can explain "promotion instead of rebuild"
- learner can verify Flux image automation across all three environments
- learner can perform and explain GitOps-first rollback

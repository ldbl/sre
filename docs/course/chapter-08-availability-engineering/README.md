# Chapter 08: Availability Engineering (HPA + PDB)

## Why This Chapter Exists

Replicas alone do not guarantee availability during disruption.
This chapter combines:
- HPA for load-based scaling
- PDB for controlled voluntary disruptions
- rollout/drain awareness

## Guardrails

- staging/production start from 2 replicas for critical services.
- each service has HPA bounds (`minReplicas`, `maxReplicas`) and resource targets.
- each service has PDB to prevent unsafe disruption.
- node drain or rollout is never executed without checking PDB/HPA state.

## Repo Mapping

- Backend overlays:
  - `flux/apps/backend/develop/`
  - `flux/apps/backend/staging/`
  - `flux/apps/backend/production/`
- Frontend overlays:
  - `flux/apps/frontend/overlays/develop/`
  - `flux/apps/frontend/overlays/staging/`
  - `flux/apps/frontend/overlays/production/`

## Current Implementation (This Repo)

- HPA (`autoscaling/v2`) added for backend and frontend in all three environments.
- PDB (`policy/v1`) added for backend and frontend in all three environments.
- staging/production baseline replicas are 2 for backend and frontend.

## Lab Files

- `lab.md`
- `quiz.md`

## Done When

- learner can verify HPA target/bounds and current scaling state
- learner can verify PDB allowed disruptions before node drain
- learner can explain interaction: HPA, PDB, rollout, and drain

# Advanced Module: Linkerd + Progressive Delivery (Canary / A-B)

## Why This Module Exists

Safe delivery is not only "deploy or rollback".
This module adds service-mesh-driven progressive rollout guardrails:
- Linkerd mTLS by default
- canary rollout with measurable abort criteria
- A/B routing with explicit experiment boundaries

## The Incident Hook

A full rollout passes smoke checks but fails under real production traffic mix.
Error rate and latency spike after deploy, and rollback starts late because detection is manual.
The team needs controlled traffic progression with automatic safety checks.

## What AI Would Propose (Brave Junior)

- "Ship 100% now; we can rollback if needed."
- "Canary is too slow for this fix."
- "Use ad-hoc routing rules without SLO checks."

Why this sounds reasonable:
- fastest short-term path
- fewer moving parts in one deploy

## Why This Is Dangerous

- blast radius is immediate and broad
- no objective stop conditions during rollout
- A/B test drift can hide impact in one segment

## Guardrails That Stop It

- traffic progression in controlled steps (for example 5% -> 25% -> 50% -> 100%)
- abort on SLO violation (error rate, latency, success rate)
- mTLS identity and policy checks before rollout
- rollback path tested before canary start

## Module Scope

1. Linkerd baseline (`check`, inject, identity, mTLS status).
2. Canary rollout flow (Flagger + Linkerd or equivalent controller).
3. A/B routing flow (header/cookie based).
4. Evidence capture for rollout decision and postmortem.

## Repository Mapping

- `flux/infrastructure/progressive-delivery/linkerd/`
- `flux/infrastructure/progressive-delivery/flagger/`
- `flux/infrastructure/progressive-delivery/develop/`
- `flux/bootstrap/flux-system/infrastructure.yaml` (Linkerd + Flagger enabled, develop canary pack opt-in)

## Files

- `lab.md`
- `runbook-linkerd-progressive-delivery.md`
- `quiz.md`

## Done When

- learner can run canary with automated abort criteria
- learner can execute bounded A/B experiment with clear success metrics
- learner can explain mesh value for rollout risk reduction

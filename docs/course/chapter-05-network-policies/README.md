# Chapter 05: Network Policies (Production Isolation)

## Why This Chapter Exists

Without network isolation, one compromised pod can move laterally across environments.
This chapter introduces a safe baseline:
- default deny
- explicit allow rules
- DNS and ingress paths opened intentionally

## The Incident Hook

A debug pod in `develop` reaches internal services it should never touch.
No exploit sophistication is needed, only open east-west traffic.
When incident starts, responders cannot quickly prove or limit blast radius.
Network policies turn this into an auditable allowlist model.

## What AI Would Propose (Brave Junior)

- "Skip policies for now to avoid breaking traffic."
- "We can secure networking later after release."

## Why This Is Dangerous

- Flat networking means high lateral-movement risk.
- Production and non-production boundaries become weak.
- Incidents are harder to contain under pressure.

## Guardrails

- Start from default deny in target namespace.
- Add minimum allow rules one by one with verification.
- Keep policy changes isolated from application changes.
- Keep rollback manifest ready before applying restrictive policies.

## Repo Mapping

- Namespace manifests: `flux/bootstrap/infrastructure/base/namespaces.yaml`
- App namespaces used in this repo: `develop`, `staging`, `production`
- Ingress usage: `flux/apps/backend/base/ingress.yaml`, `flux/apps/frontend/base/ingress.yaml`
- NetworkPolicy manifests: `flux/infrastructure/network-policies/base/`
- Flux wiring: `flux/bootstrap/flux-system/infrastructure.yaml`, `flux/bootstrap/flux-system/apps.yaml`

## Lab Files

- `lab.md`
- `quiz.md`

## Done When

- learner can apply default deny without losing control of the environment
- learner can allow only required DNS + ingress traffic
- learner can debug and explain blocked traffic with evidence

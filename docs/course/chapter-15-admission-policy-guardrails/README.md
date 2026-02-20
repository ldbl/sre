# Chapter 15: Admission Policy Guardrails (Advanced)

## Why This Chapter Exists

Local checks (pre-commit, CI, review) reduce risk but can be bypassed.
Admission control is the last enforcement point before runtime.

This chapter focuses on policy-as-code guardrails that block risky workloads even when upstream checks fail.

## Learning Objectives

By the end of this chapter, learners can:
- explain why cluster-side policy is mandatory in production systems
- roll out Kyverno rules with `Audit -> Enforce` safely
- troubleshoot deny events and remediate manifests correctly
- run controlled break-glass exceptions with expiry and audit trail

## The Incident Hook

A workload is deployed during incident pressure with missing limits, mutable tags, and weak security context.
Workstation hooks were skipped and review focused on speed.
The pod starts in a risky configuration and causes noisy-neighbor impact.
Recovery is slowed because the team lacks clear deny/exception discipline.

## What AI Would Propose (Brave Junior)

- "Disable the policy engine temporarily."
- "Allow privileged mode now, fix later."
- "Create a broad exception for the whole namespace."

Why this sounds reasonable:
- immediate progress under pressure
- lower friction in the moment

## Why This Is Dangerous

- Security and stability regressions reach runtime.
- "Temporary" exceptions become long-term drift.
- Platform trust model is weakened for all teams.

## Guardrails That Stop It

- Policy engine always-on (Kyverno).
- Default rollout path: `Audit` then selective `Enforce`.
- Exceptions must be scoped, time-bound, and approved.
- Deny evidence is mandatory before policy changes.

## Current Platform State

- Kyverno engine is active via Flux:
  `flux/infrastructure/policy/kyverno/`
- Chapter 15 policies are scaffolded and inactive by default:
  `flux/infrastructure/policy/packs/chapter-15-admission-guardrails/`

## Repository Mapping

- Engine:
  - `flux/infrastructure/policy/kyverno/kustomization.yaml`
  - `flux/infrastructure/policy/kyverno/release.yaml`
- Starter pack templates:
  - `flux/infrastructure/policy/packs/chapter-15-admission-guardrails/disallow-latest-tag.example.yaml`
  - `flux/infrastructure/policy/packs/chapter-15-admission-guardrails/require-security-context.example.yaml`
  - `flux/infrastructure/policy/packs/chapter-15-admission-guardrails/require-requests-limits.example.yaml`
- Workloads under control: `flux/apps/**/`

## Safe Workflow (Step-by-Step)

1. Enable selected policies in `Audit`.
2. Trigger known violations intentionally in `develop`.
3. Review policy reports and event messages.
4. Fix manifests, not engine settings.
5. Move stable rules to `Enforce` in non-production.
6. Promote enforcement gradually across environments.

## Lab Files

- `lab.md`
- `runbook-admission-policy.md`
- `quiz.md`

## Done When

- learner demonstrates `Audit -> Enforce` with clear evidence
- learner can perform deny triage and manifest remediation
- learner can apply a safe exception process without global bypass

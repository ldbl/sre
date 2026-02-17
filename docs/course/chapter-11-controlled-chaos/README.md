# Chapter 11: Controlled Chaos

## Why This Chapter Exists

Production resilience is not proven in calm conditions.
This chapter validates behavior under controlled failures with explicit blast-radius limits.

## Scope

Failure classes in this chapter:
- crash loop (`/panic`)
- elevated 5xx (`/status/500`)
- random pod termination (Chaos Monkey)

Current implementation focus:
- deterministic drills first
- Chaos Monkey in `develop` with kill switch and strict target allowlist

## Chaos Monkey (MVP)

Flux path:
- `flux/infrastructure/chaos/develop/`

Safety controls:
- namespace scope: `develop` only (RBAC Role in `develop`)
- target scope: `app=frontend` or `app=backend`
- schedule: every 15 minutes
- window: UTC `10-16`
- kill switch: `spec.suspend: true` on CronJob (default)

## Guardrails

- Never run uncontrolled chaos in `staging`/`production`.
- One failure injection per run.
- Evidence-first triage: metrics -> traces -> logs.
- Every drill must end with recovery verification and a hardening action.

## Lab Files

- `lab.md`
- `runbook-game-day.md`
- `scorecard.md`
- `quiz.md`

## Handoff to Chapter 12 (AI Guardian)

Chaos Monkey emits structured log events in CronJob output.
In Chapter 12, Guardian watchers consume these events and classify:
- expected controlled disruption
- unexpected collateral impact
- escalation-required incident

## Done When

- learner runs at least two controlled failure drills with evidence
- learner enables/disables Chaos Monkey safely
- learner captures one game-day scorecard with action items

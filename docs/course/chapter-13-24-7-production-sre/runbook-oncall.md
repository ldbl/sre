# Runbook: On-Call Incident Operations

## Severity Matrix

- SEV-1: active customer outage or high data-risk
- SEV-2: major degradation with customer impact
- SEV-3: limited/contained issue, no major customer impact

## Standard Timeline

1. 0-5 min:
- acknowledge alert
- appoint IC
- declare severity and channel

2. 5-15 min:
- confirm symptom via metrics
- trace/log correlation
- first mitigation proposal

3. 15-30 min:
- execute lowest-risk mitigation
- status updates on cadence

4. 30+ min:
- verify recovery
- downgrade/close incident when stable
- create postmortem task

## Communications Template

- Current status:
- Impact:
- Scope:
- Action in progress:
- Next update in:

## Decision Rules

- No rollback/hotfix without evidence package.
- Prefer reversible mitigation first.
- If uncertainty remains high, reduce blast radius before deeper fixes.

## Incident Closure Checklist

- service indicators back to baseline
- no active critical symptom for agreed window
- postmortem owner assigned
- hardening action items created

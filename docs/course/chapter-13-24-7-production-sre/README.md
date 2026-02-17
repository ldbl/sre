# Chapter 13: 24/7 Production SRE

## Why This Chapter Exists

Tooling is not enough without operational discipline.
This chapter defines how teams run incidents, reduce recurrence, and harden systems continuously.

## Scope

- on-call operating model
- incident lifecycle and severity policy
- recurring-problem management
- blameless postmortem workflow
- AI boundary policy in production

## Core Principles

1. Evidence first:
- metrics + traces + logs before high-risk actions

2. Blameless response:
- focus on system conditions and guardrail gaps, not individuals

3. Controlled escalation:
- severity-based comms and ownership

4. AI boundary:
- AI can classify and recommend
- humans own decisions and execution

## Operating Model

- Incident Commander (IC)
- Primary Responder
- Communications Owner
- Scribe

## Lab Files

- `lab.md`
- `runbook-oncall.md`
- `postmortem-template.md`
- `quiz.md`

## Done When

- learner can run a full incident timeline with roles and severity
- learner can produce a complete blameless postmortem
- learner can define hardening actions with owner and due date

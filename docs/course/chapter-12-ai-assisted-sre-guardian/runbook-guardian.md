# Runbook: AI Guardian Operations (Draft)

## Purpose

Operate the guardian as a safe incident triage layer, not an auto-remediation engine.

## Runtime Checks

1. Health:

```bash
curl -s http://localhost:8080/healthz
```

2. Recent incidents:

```bash
curl -s http://localhost:8080/incidents | jq
```

3. LLM usage and rate:

```bash
curl -s "http://localhost:8080/llm-usage?hours=24" | jq
```

## Incident Handling Workflow

1. Confirm symptom in platform observability.
2. Open guardian incident detail.
3. Validate confidence and evidence:
- if low confidence, require manual deep-dive
- if high confidence with strong evidence, apply runbook action
4. Ack incident when ownership is clear.
5. Resolve only after recovery verification.

## Escalation Logic

- recurring incidents should raise urgency
- persistent incidents should trigger hardening task with owner/due date
- no closure without verified mitigation

## Security & Compliance Checks

- ensure sanitizer policy is active
- verify no plaintext secrets in incident payloads
- rotate API tokens regularly

## Failure Modes

1. LLM unavailable:
- continue with raw context and manual triage
- avoid blocking incident response

2. SQLite unavailable:
- fallback to configmap mode if needed for continuity
- restore SQLite for full incident lifecycle features

3. Alert storm:
- tune dedup/cooldown thresholds
- reduce scanner frequency temporarily

# Chapter 12: AI-Assisted SRE Guardian (Draft)

## Why This Chapter Exists

Chaos testing and alerts generate noise unless incidents are normalized and prioritized.
This chapter introduces an AI-assisted guardian that analyzes incidents, proposes actions, and escalates safely without auto-fixing production.

## Scope (Current Draft)

Implementation target is `../k8s-ai-monitor/`:
- Kopf operator handlers for events and Flux objects
- scanner loops for pod/pvc/certificate/endpoint
- LLM analysis with strict JSON schema
- incident lifecycle backend (SQLite preferred)
- confidence-based human escalation

## Guardian Responsibilities

1. Detect:
- Kubernetes Warning events
- Flux stalled conditions
- periodic scanner findings

2. Analyze:
- collect structured context
- sanitize sensitive data
- enforce context budget
- call LLM for structured root-cause hypotheses

3. Decide:
- create/update incident record
- deduplicate repeated noise
- escalate recurring/persistent incidents

4. Notify:
- send structured alert
- expose incident APIs for ack/resolve

## Guardrails

- AI proposes; human approves remediation.
- No autonomous write-back to production workloads.
- Confidence < threshold implies explicit human review.
- Secret/token redaction is mandatory before LLM call.
- Rate and cost limits are mandatory.

## Repository Mapping

- Guardian config: `../k8s-ai-monitor/src/config.py`
- Event handlers: `../k8s-ai-monitor/src/handlers/events.py`, `../k8s-ai-monitor/src/handlers/flux.py`
- Scanner startup loops + HTTP API: `../k8s-ai-monitor/src/handlers/startup.py`
- Processing pipeline: `../k8s-ai-monitor/src/engine/pipeline.py`
- LLM schema + cost tracking: `../k8s-ai-monitor/src/engine/llm.py`
- Sanitizer: `../k8s-ai-monitor/src/engine/sanitizer.py`
- Incident store: `../k8s-ai-monitor/src/engine/store/sqlite.py`

## Lab Files

- `lab.md`
- `runbook-guardian.md`
- `quiz.md`

## Done When (MVP)

- guardian catches one Chapter 11 chaos scenario
- incident is persisted with structured analysis and confidence
- on-call can ack/resolve incident via API
- one escalation scenario is demonstrated (recurring or persistent)

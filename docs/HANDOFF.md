# Handoff (ChatGPT ↔ Repo)

This file is a copy/paste bridge between this repo work and phone-based ChatGPT discussions.

## Context To Paste Into ChatGPT

```text
Контекст (repo + курс):
Правим guardrails-first курс/репо: AI в DevOps/SRE без да увеличаваме risk/blast radius.

Repo: monorepo `sre/` със:
- `infra/terraform/hcloud_cluster/` (Hetzner: 1x cx23 control-plane + 1x cx23 worker) + Flux bootstrap.
- Terraform state: Cloudflare R2 (S3 backend + use_lockfile).
- Deploy: Flux GitOps (namespaces develop/staging/production).
- CI: GitHub Actions build/push (backend/frontend) + terraform plan/apply workflows.
- `backend/` Go service: metrics (/metrics), health probes, tracing (Uptrace), chaos endpoints.
- `frontend/` Vue app: dashboard + web tracing.

Цели (end-to-end): IaC best practices, Kubernetes deploy best practices, microservices best practices,
observability (Prometheus/logging/tracing), versions/releases/promotion with traceability, agentskills.io skills,
AI-assisted GitOps service (read-only advisor), anti-patterns (какво НЕ трябва да се прави).

Питай/предложи:
- идеи за Lesson 01 (силен инцидентен сценарий) + safe path / failure path
- как да структурираме курса и demo-тата
- какви guardrails да са задължителни
```

## Output To Paste Back Into Repo (From ChatGPT)

```text
ChatGPT output:

- Decisions:

- Lesson ideas:

- Risks/concerns:

- Concrete next steps in repo:

- Suggested files/paths to change:

- Any scripts/checklists suggested:
```


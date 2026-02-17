# SRE Control Plane Plan (Guardrails-First)

## Core Concept

This is not a beginner DevOps course and not a prompting course.

This repo/course is about using AI in DevOps / SysOps / SRE **without increasing risk or blast radius**. AI is treated like a very fast junior engineer: good with tooling, low context, confident, and indifferent to prod vs dev.

The goal is to build workflows where AI is a reviewer/simulator/second brain, not an executor.

## Repo Goals

- Provide a realistic, production-ish demo repo with `backend/`, `frontend/`, Terraform, Flux GitOps, and observability.
- Teach guardrails-first workflows: environment separation, plan-before-apply, context checks, blast radius control, rollback-first.
- Keep everything evergreen and workflow-oriented (not tool-hype or tool-churn).

## Course Blueprint (Approved)

The course now follows a 13-chapter structure:

1. Production Mindset & Guardrails
2. Infrastructure as Code (IaC)
3. Secrets Management (SOPS)
4. GitOps & Version Promotion
5. Network Policies (Production Isolation)
6. Security Context & Pod Hardening
7. Resource Management & QoS
8. Availability Engineering (HPA + PDB)
9. Observability
10. Backup & Restore Basics
11. Controlled Chaos
12. AI-Assisted SRE Guardian
13. 24/7 Production SRE

Canonical reference: `docs/course/CURRICULUM.md`.

## End-to-End Scope (What We Must Demonstrate)

1. IaC / Terraform (cluster provisioning + best practices): remote state, locking, plan/apply split, least privilege, predictable outputs.
2. Kubernetes deploy best practices: namespaces per env, safe rollouts, resource limits, health probes, ingress, RBAC, config separation.
3. Microservices for Kubernetes best practices: containerization, health endpoints, graceful shutdown, structured logs, metrics, traces.
4. Observability: Prometheus metrics, central logging, Uptrace tracing (or equivalent), plus a realistic “debug the incident” workflow.
5. Versions & releases: traceability from commit → image tag → deployment; promotion to production with approvals and audit trail.
6. Agent Skills (agentskills.io): package repeatable, auditable AI workflows as skills (review-only, checklists, generators).
7. AI-assisted GitOps/DevOps: a cluster service that reviews state and reports (read-only), reacts to events/questions, and reduces toil safely.
8. Anti-patterns: show what not to do (unsafe automation, wrong context, correlated changes) and how guardrails prevent incidents.

## Platform Decisions (As Of 2026-02-03)

- Primary runtime: Hetzner Cloud Kubernetes (k3s via `kube-hetzner`).
- Cluster topology: 1x `cx23` control-plane + 1x `cx23` worker.
- Environments: single cluster with namespaces `develop`, `staging`, `production`.
- GitOps: Flux (deploy is pull-based; CI builds/pushes images).
- IaC: Terraform.
- Terraform remote state: Cloudflare R2 (S3 backend + `use_lockfile`).
- CI: GitHub Actions.
- Local option: kind (kept for fast feedback, but not the main path).

## Current Status (As Of 2026-02-03)

Completed:
- Monorepo structure under `sre/` (single git repo).
- Reference services: `backend/` (metrics/tracing/chaos endpoints) and `frontend/` (demo UI + web tracing).
- Flux manifests for apps + environments under `flux/`.
- GitHub Actions for backend/frontend build and push.
- Terraform skeleton for Hetzner under `infra/terraform/hcloud_cluster/` with R2 backend.
- Terraform GitHub Actions workflows: plan (PR) and manual apply/destroy.

Pending / Needs hardening:
- Decide Flux auth model for repo sync (public repo vs private repo token vs GitHub App).
- Ingress controller strategy for Hetzner and DNS/TLS story (currently Ingress hosts default to `*.local`).
- Secrets workflow finalization (SOPS/age key management + when to wire `flux/secrets/**`).
- Observability stack end-to-end (Prometheus/Grafana/Loki/traces) as a cohesive demo with runbooks.

## Milestones

### Milestone 1: Hetzner Bootstrap (MVP)

Definition of done:
- `Terraform - Apply (Hetzner)` creates cluster reliably and produces kubeconfig.
- Flux installed and syncing `./flux/bootstrap/flux-system`.
- Namespaces exist and app deployments reconcile via Flux.
- A simple ingress path works (even if Host-header based), so demos are reachable.

### Milestone 2: Lesson 01 (Guardrails Story)

Definition of done:
- One incident-style lesson demonstrating “AI breaks more than one thing at a time”.
- Demo includes a failure path and a safe path.
- Repo artifacts: scripts/commands, expected outputs, and a checklist students follow.

### Milestone 3: Guardrails Library (Reusable)

Definition of done:
- Guard scripts that enforce:
- plan/apply split
- context checks (cluster/namespace/environment)
- diff-only workflows
- locking/concurrency limits
- read-only AI access patterns
- Each guardrail is demonstrated in a lab and backed by a test or a deterministic check.

### Milestone 4: Observability Demos (Pain-Driven)

Definition of done:
- Metrics: dashboards + a handful of meaningful alerts.
- Logs: a central pipeline with a realistic query workflow.
- Traces: end-to-end trace from frontend → backend.
- Each has a “false sense of safety” anti-pattern example and a “safe workflow” example.

### Milestone 5: Promotion & Versioning (Last)

Definition of done:
- Clear promotion path to production (manual gate).
- Optional: Flux ImageUpdateAutomation Git write-back with separate credentials (least privilege).
- Releases/versioning added only after guardrails are in place.

## Priority Backlog (Next 1-2 Weeks)

1. Make Hetzner workflow truly runnable end-to-end (credentials checklist + apply + Flux sync verification).
2. Add ingress-nginx (or confirm `kube-hetzner` provisions it) and document access method.
3. Choose and document Flux Git auth model (public repo recommended for training).
4. Write Lesson 01 as markdown under `docs/course/` and implement the demo commands/scripts.
5. Add safety-focused “golden paths”:
6. Terraform: `plan` output review checklist.
7. Kubernetes: context/namespace checks before any change.
8. CI/CD: concurrency controls and change batching guidance.

## Suggested Implementation Order (So It Lands Cleanly)

1. IaC: finish `infra/terraform/hcloud_cluster/` + workflows, then make Flux reconcile successfully.
2. Kubernetes: make `flux/` deploy backend+frontend reliably to `develop` first, then stage/prod.
3. Services: tighten `backend/` and `frontend/` as “reference implementations” (logging/metrics/tracing knobs).
4. Observability: ship dashboards + a small number of actionable alerts + a single tracing story.
5. Release/promotion: add versioning and promotion only after guardrails exist (avoid early “automation without rollback”).
6. Agent skills: add a `skills/` directory with SKILL.md modules for safe review/checklist/report workflows.
7. AI-assisted GitOps service: add a read-only “advisor” that produces reports, never executes changes.

## Success Metrics

- Students can use AI to propose changes, but the workflow prevents unsafe execution by default.
- Students can demonstrate safe promotion and safe rollback.
- Students can explain correlated failures and how guardrails reduce blast radius.
- The demo repo can be spun up from scratch in < 60 minutes with predictable results.

## Execution Plan (As Of 2026-02-16)

### Current State Snapshot

Done recently:
- Core docs are aligned with the active architecture and Flux image-automation flow.
- Backend unit tests are green after Swagger endpoint test alignment (`/swagger/index.html`).
- Terraform kind output now references `sre-control-plane` context consistently.

Open gaps:
- `docs/course/` is still scaffold-only (no full Lesson 01 content yet).
- `tests/` in `sre/` has no real validation suite yet.
- Observability is partial: kube-prometheus-stack is wired, but OpenTelemetry collector bootstrap is still disabled.
- Hetzner production path still needs one reproducible runbook from credentials to successful Flux reconciliation and ingress verification.
- Flux auth model should be finalized/documented as one canonical option (public repo vs token vs GitHub App).

### Phase 1 (Next 2-3 Days): Stabilize Baseline

Definition of done:
- Working tree cleaned with focused commits for:
  - docs consistency updates
  - backend Swagger test fix
  - terraform context output fix
- `sre` branch synced with `origin/main`.
- Quick verification checklist executed locally:
  - `go test ./...` in `backend`
  - `terraform validate` for `infra/terraform/kind_cluster`
  - `terraform validate` for `infra/terraform/hcloud_cluster`

### Phase 2 (Next 3-5 Days): Close Hetzner MVP Path

Definition of done:
- Single authoritative runbook in `docs/hetzner.md` for:
  - required secrets
  - workflow order (plan -> apply)
  - post-apply checks (cluster, flux, namespaces, app health)
  - ingress verification with Host header
- One explicit decision documented for Flux repo auth model.
- One explicit DNS/TLS short-term strategy documented for demos.

### Phase 3 (Next 5-7 Days): Lesson 01 + Guardrails

Definition of done:
- Create first complete lesson under `docs/course/chapter-01-introduction/`:
  - incident hook
  - unsafe path
  - safe path
  - reproducible demo commands
  - rollback checklist
- Add reusable guard scripts under `scripts/` for:
  - Kubernetes context/namespace pre-check
  - Terraform plan-before-apply enforcement
- Link lesson to scripts and expected outputs.
- Start migration of chapter placeholders to the approved 13-chapter blueprint.

### Phase 4 (Next 7-10 Days): Observability End-to-End

Definition of done:
- Direct export to Uptrace is documented and used by frontend/backend (no in-cluster OTel collector in MVP).
- Demonstrate one trace path frontend -> backend with runbook.
- Add one incident-debug workflow in docs using metrics + traces (+ logs where available).

### Phase 5 (Next 10-14 Days): Minimal Test Harness

Definition of done:
- Add initial test suite under `tests/`:
  - docs/manifest sanity checks
  - deterministic checks for guard scripts
  - basic Flux object presence assertions (manifest-level)
- Wire these checks into CI as non-optional for PRs affecting `flux/`, `infra/`, or `docs/`.

### Phase 6 (Course Productization): Curriculum Execution

Definition of done:
- Full chapter-by-chapter lab plans aligned to `docs/course/CURRICULUM.md`.
- Duration estimate finalized (hours).
- Target learner profile finalized (mid/senior).
- Strong opening and closing module scripts prepared.

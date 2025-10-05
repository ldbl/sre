# SRE Control Plane Demo

This repository captures a production-inspired SRE/DevOps control plane used for course-ready demonstrations. It illustrates infrastructure-as-code, GitOps automation, observability, and security best practices across multiple environments.

## Current Decisions
- Frontend: Vue 3 SPA (Vite) under `src/frontend`
- Backend: Go 1.23 HTTP API under `src/backend`
- Local Kubernetes: kind
- GitOps operator: FluxCD
- IaC layout: Terraform under `infra/terraform`, Kubernetes manifests under `infra/kubernetes`, shared modules in `infra/modules`
- Automation code roots: `src/` for services/apps, `scripts/` for reusable tooling, mirrored tests under `tests/`

## Repository Layout (WIP)
- `docs/` – living documentation, runbooks, and course material
- `infra/` – Terraform, Kubernetes manifests, and shared modules
- `infra/terraform/kind_cluster/` – Terraform module (tehcyx/kind) defining the multi-node kind cluster
- `src/backend/` – Go backend service (Podinfo-inspired HTTP API)
- `src/frontend/` – Vue frontend application
- `tests/` – unit, integration, and system test suites
- `scripts/` – helper scripts, lint/test wrappers
- `config/examples/` – redacted configuration samples (never secrets)

### Backend Highlights
- `/healthz`, `/readyz`, `/livez` with toggle endpoints for readiness/liveness drills
- `/status/{code}`, `/delay/{seconds}`, `/panic`, `/echo`, `/headers`, `/env` to simulate failure modes and introspect runtime state
- `/metrics` (Prometheus registry), `/openapi` (machine spec), and `/swagger` (Swagger UI) for observability and discoverability
- HTML landing page sourcing `UI_MESSAGE`, `UI_COLOR`, `APP_VERSION`, and `APP_COMMIT`
- Optional request chaos via `RANDOM_DELAY_MAX` (milliseconds) and `RANDOM_ERROR_RATE` (0–1) environment variables or flags
- Version (SemVer by default), commit (full & short), and build timestamp (`build_time`) embedded at compile time via Go ldflags (exposed on `/version`, `/openapi`, and the landing page)

## Getting Started
1. Install system prerequisites: Docker (running), `curl`, `tar`, `unzip`, Go 1.23+, Node.js 20+, and npm.
2. Install the Kubernetes/IaC CLIs manually (recommended versions): Terraform 1.13.3, kubectl 1.34.1, kind 0.30.0.
3. Provision the local kind cluster via Terraform (`infra/terraform/kind_cluster`) – this also installs Flux controllers automatically.
4. Run the backend locally with `cd src/backend && go run ./cmd/api`, or build a container image via `make -C src/backend image` (injects git metadata into the binary). Frontend scaffolding will land under `src/frontend`.
5. Publish the backend image to GitHub Container Registry with `make backend-publish`. Export `DOCKER_PAT` (PAT with `write:packages`) and optionally `DOCKER_USER` before running; override `REGISTRY_HOST`, `REGISTRY_NAMESPACE`, `IMAGE_NAME`, or `TAG` as needed.
6. Follow `docs/local-dev.md` for extra tips (Terraform workflow, local registry, manual commands) and advanced workflows.

To enable GitOps reconciliation of this repository, set `TF_VAR_flux_git_repository_url` (and optional branch/path variables) before running Terraform. See `docs/gitops/flux.md` for details.

Track build-out progress in `PLAN.md`. Milestone 1 focuses on repository scaffolding, baseline automation targets, and seed service skeletons.

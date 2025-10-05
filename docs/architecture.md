# Architecture Overview

## Technical Stack Decisions
- **Frontend:** Vue 3 SPA (Vite toolchain) communicating with backend via REST/JSON
- **Backend:** Go 1.23 HTTP API providing health checks, metrics, and business endpoints
- **Kubernetes Distribution:** kind for local development; managed Kubernetes (TBD) for stage/prod scenarios
- **GitOps Operator:** FluxCD for reconciliation, image automation, and policy enforcement
- **Infrastructure as Code:** Terraform for cloud resources, Kubernetes manifests via Kustomize overlays
- **Observability:** Prometheus + Alertmanager, Grafana dashboards, Loki for logs, OpenTelemetry instrumentation

> Tooling versions for cluster/IaC utilities are pinned in the `Makefile`; run `make versions` to confirm local binaries match expectations.

## Repository Modules
- `src/backend/` – Go HTTP API with Podinfo-style health probes, chaos endpoints, Prometheus metrics, and HTML landing page
- `src/frontend/` – Vue SPA consuming backend APIs and exposing dashboards/forms for demos
- `infra/terraform/` – Environment workspaces (`environments/dev`, `stage`, `prod`) and reusable modules under `infra/modules`
- `infra/kubernetes/` – Base manifests plus environment overlays (`base/`, `overlays/dev|stage|prod`), kind-specific config under `kind/`
- `docs/runbooks/` – Incident guides, SLO playbooks, and testing notes

## Backend Capabilities
- HTTP surface: `/healthz`, `/readyz`, `/livez`, `/status/{code}`, `/delay/{seconds}`, `/panic`, `/env`, `/headers`, `/echo`, `/version`, `/openapi`, `/swagger`, `/metrics`
- Toggle readiness/liveness via `PUT /readyz/enable|disable` and `PUT /livez/enable|disable` for probe demonstrations
- HTML root page renders `UI_MESSAGE`, `UI_COLOR`, `APP_VERSION`, and `APP_COMMIT`
- Chaos engineering knobs: `RANDOM_DELAY_MAX` (milliseconds) and `RANDOM_ERROR_RATE` (0–1) for request delay/error injection
- Prometheus registry with process/go collectors and request instrumentation for SLO dashboards; OpenAPI 3 spec served at `/openapi` with Swagger UI at `/swagger`
- Build metadata (SemVer version by default, commit full & short, build timestamp via `build_time`) injected via ldflags and surfaced on `/version`, `/swagger`, and the landing page
- Container image produced via `src/backend/Dockerfile` (multi-stage, distroless-style Alpine runtime) and `make -C src/backend image`

## Delivery Pipeline
1. **Pre-commit (planned):** format, lint, security scan hooks
2. **CI Pipeline (GitHub Actions):** lint → unit tests → integration tests → build & scan container images → Terraform plan
3. **GitOps Deployment:** FluxCD applies Kubernetes state to dev/stage clusters; production requires manual approval

## Observability & SLOs
- Service-level indicators: request latency (p95), error rate, and frontend availability metrics
- SLO dashboards stored in `observability/grafana/`
- Alert routing via Alertmanager to Slack/email (mocked for demo)

## Security & Compliance
- Secrets managed via External Secrets Operator bridged to demo vault backend
- Supply chain hardening using Cosign signing and SBOM generation (Syft/Grype)
- Quarterly audit tasks tracked in `docs/security/security-calendar.md`

## Outstanding Decisions
- Cloud provider for Terraform resource demonstrations (AWS vs. GCP vs. Azure)
- Persistent storage solution for local clusters (local-path, rook-ceph, etc.)
- DR strategy automation tooling (Velero or cloud-native backups)

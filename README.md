# SRE Control Plane

This repository contains the SRE/DevOps infrastructure and GitOps configuration. It illustrates infrastructure-as-code, GitOps automation, observability, and security best practices across multiple environments.

## Current Decisions
- Application repositories: Separate repos for [backend](https://github.com/ldbl/backend) and [frontend](https://github.com/ldbl/frontend)
- Local Kubernetes: kind
- GitOps operator: FluxCD
- IaC layout: Terraform under `infra/terraform`, Kubernetes manifests under `infra/kubernetes`, shared modules in `infra/modules`
- Automation: `scripts/` for reusable tooling, `tests/` for infrastructure tests

## Repository Layout
- `docs/` – living documentation, runbooks, and course material
- `infra/` – Terraform, Kubernetes manifests, and shared modules
- `infra/terraform/kind_cluster/` – Terraform module (tehcyx/kind) defining the multi-node kind cluster
- `flux/` – FluxCD GitOps configuration
- `config/` – shared configuration files
- `tests/` – infrastructure and system test suites
- `scripts/` – helper scripts, automation wrappers

## Getting Started
1. Install system prerequisites: Docker (running), `curl`, `tar`, `unzip`.
2. Install the Kubernetes/IaC CLIs manually (recommended versions): Terraform 1.13.3, kubectl 1.34.1, kind 0.30.0, flux 2.7.0.
3. Provision the local kind cluster via Terraform (`infra/terraform/kind_cluster`) – this also installs Flux controllers automatically.
4. Follow `docs/local-dev.md` for extra tips (Terraform workflow, local registry, manual commands) and advanced workflows.

To enable GitOps reconciliation of this repository, set `TF_VAR_flux_git_repository_url` (and optional branch/path variables) before running Terraform. See `docs/gitops/flux.md` for details.

Track build-out progress in `PLAN.md`.

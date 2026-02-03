# Hetzner (hcloud) Cluster

This repository supports a single Hetzner cluster (1x `cx23` control-plane + 1x `cx23` worker) with namespaces `develop`, `staging`, and `production`. Deployments are GitOps-managed by Flux.

Terraform runs from GitHub Actions. Remote state is stored in Cloudflare R2 (S3-compatible backend).

## Required GitHub Secrets

Create these under GitHub → repo → Settings → Secrets and variables → Actions:

- `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY`: Cloudflare R2 access keys for the `sre` bucket (Terraform state backend).
- `HCLOUD_TOKEN`: Hetzner Cloud API token.
- `HCLOUD_SSH_PUBLIC_KEY`: SSH public key (ed25519) used to bootstrap nodes.
- `HCLOUD_SSH_PRIVATE_KEY`: SSH private key (ed25519) used to bootstrap nodes.

Recommended (but depends on your setup):

- `FLUX_GIT_TOKEN`: Only needed if the GitHub repo is private. Fine-grained token with repository access and `Contents: Read` permission (classic PAT: `repo` scope).
- `SOPS_AGE_KEY`: age private key (contents of `age.agekey`) so Flux can decrypt SOPS secrets from `flux/secrets/**`.
- `GHCR_USERNAME` / `GHCR_TOKEN`: Only needed if container images in GHCR are private (`GHCR_TOKEN` needs `read:packages`).

## Terraform Workflows

- `Terraform - Plan (Hetzner)`: runs on PRs that touch `infra/terraform/hcloud_cluster/**` or `flux/**`.
- `Terraform - Apply (Hetzner)`: manual (`workflow_dispatch`), protected by the GitHub Environment `hcloud` (configure approvals in GitHub).

## Notes

If your GitHub org/user is not `ldbl` (the current placeholder), run `scripts/configure-repo.sh --github-owner <owner> --github-repo <repo>`. This updates hardcoded `ghcr.io/<owner>` and `https://github.com/<owner>/<repo>.git` references in `docs/` and `flux/`.

Secrets under `flux/secrets/**` are currently opt-in. When you are ready, wire them by adding `flux/bootstrap/flux-system/secrets.yaml` to `flux/bootstrap/flux-system/kustomization.yaml` and ensure `sops-age` exists in `flux-system`.

Ingress hostnames in this repo default to `backend.local` / `frontend.local`. For demos you can hit the load balancer IP and set the Host header (or add `/etc/hosts` entries).

The Hetzner k3s setup from `kube-hetzner` expects MicroOS snapshots to exist in your Hetzner project (created once via their tooling). If you don’t have those snapshots yet, create them before running Terraform.

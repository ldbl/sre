# Flux GitOps Configuration

This directory contains Flux GitOps manifests for the SRE infrastructure.

## Directory Structure

```
flux/
├── apps/                    # Application deployments
├── infrastructure/          # Infrastructure components (monitoring, ingress, etc.)
└── clusters/               # Cluster-specific configurations
    └── sre-kind/           # Kind cluster configuration
        ├── flux-system/    # Flux system resources
        └── apps.yaml       # Application kustomizations
```

## Flux Reconciliation

The Flux controllers in the `sre-kind` cluster are configured to reconcile from:
- **Repository:** `git@github.com:ldbl/sre.git`
- **Branch:** `main`
- **Path:** `./flux/clusters/sre-kind`

## How it works

1. Flux monitors this repository for changes
2. When changes are detected, Flux applies them to the cluster
3. All changes are declarative and version-controlled

## Adding new applications

1. Create manifests in `flux/apps/<app-name>/`
2. Create a Kustomization in `flux/clusters/sre-kind/` to reference the app
3. Commit and push changes
4. Flux will automatically deploy the application

## Monitoring

```bash
# Check Flux status
flux check

# View all Flux sources
flux get sources all

# View all Flux kustomizations
flux get kustomizations

# Reconcile immediately (force sync)
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

# GitOps Workflow and Deployment Process

## Overview

This repository uses FluxCD for GitOps-based continuous delivery across three environments:
- **Development** (`develop` namespace) - Auto-deployed from `develop` branch
- **Staging** (`staging` namespace) - Auto-deployed from `main` branch
- **Production** (`production` namespace) - Manually promoted from staging

## Environment Architecture

```
┌─────────────┐
│   develop   │──→ Build v1.2.3-rc.{sha} ──→ Auto-deploy to develop namespace (RC Testing)
│   branch    │
└─────────────┘
       │
       │ PR + Merge
       ▼
┌─────────────┐
│    main     │──→ Build v1.2.3 (stable) ──→ Auto-deploy to staging namespace
│   branch    │                                         │
└─────────────┘                                         │ Tests pass + QA
                                                        ▼
                                             ┌─────────────────────┐
                                             │ Manual Promotion    │
                                             │ (workflow_dispatch) │
                                             │ Tag: production-    │
                                             │ latest              │
                                             └─────────────────────┘
                                                        │
                                                        │ Same v1.2.3 image
                                                        ▼
                                             ┌─────────────────────┐
                                             │ production namespace│
                                             │ (v1.2.3)            │
                                             └─────────────────────┘
```

## Image Tagging Strategy

### Development (RC Testing)
- **Format:** `v{major}.{minor}.{patch}-rc.{git-sha}`
- **Example:** `v0.1.0-rc.a1b2c3d`
- **Build Trigger:** Push to `develop` branch
- **Deployment:** Automatic via Flux ResourceSet
- **Purpose:** Test release candidates before promoting to staging

### Staging (Stable Pre-Production)
- **Format:** `v{major}.{minor}.{patch}`
- **Example:** `v1.2.3`
- **Build Trigger:** Merge to `main` branch (from develop PR)
- **Deployment:** Automatic via Flux ResourceSet
- **Purpose:** Final validation before production with stable version

### Production
- **Format:** `v{major}.{minor}.{patch}` (same as staging)
- **Example:** `v1.2.3`
- **Build Trigger:** Manual workflow dispatch
- **Deployment:** Uses exact same image as staging (guaranteed consistency)
- **Purpose:** Production deployment with manual approval gate

## Deployment Workflows

### 1. Development Deployment

**Trigger:** Push to `develop` branch

```bash
# Make changes in develop branch
git checkout develop
git add .
git commit -m "feat: add new feature"
git push origin develop
```

**Process:**
1. GitHub Actions builds image with tag `dev-{sha}-{ts}`
2. Image pushed to `ghcr.io/ldbl/backend:dev-{sha}-{ts}`
3. Flux ImagePolicy `backend-develop` detects new image
4. Flux updates deployment in `develop` namespace
5. Changes auto-deployed within 1-2 minutes

**Monitoring:**
```bash
# Watch Flux reconciliation
kubectl get kustomizations -n flux-system -w

# Check deployment status
kubectl get deployments -n develop

# View logs
kubectl logs -n develop -l app=backend --tail=50
```

### 2. Staging Deployment

**Trigger:** Push to `main` branch (typically via PR from develop)

```bash
# Create PR from develop to main
gh pr create --base main --head develop --title "Release v1.2.3"

# After PR approval and merge
# GitHub Actions automatically:
# 1. Builds RC image
# 2. Runs integration tests
# 3. Pushes to registry
```

**Process:**
1. GitHub Actions builds image with tag `v{version}-rc.{run}`
2. Integration tests run automatically
3. Image pushed to `ghcr.io/ldbl/backend:v1.2.3-rc.4`
4. Flux ImagePolicy `backend-staging` detects new RC
5. Flux updates deployment in `staging` namespace
6. Automatic deployment within 5 minutes

**Validation:**
```bash
# Check staging deployment
kubectl get deployments -n staging

# Run manual smoke tests
curl https://staging.example.com/health

# Review logs for errors
kubectl logs -n staging -l app=backend --tail=100
```

### 3. Production Promotion

**Trigger:** Manual workflow dispatch

**Prerequisites:**
- [ ] Staging deployment successful
- [ ] Integration tests passed
- [ ] Manual QA completed
- [ ] Stakeholders notified
- [ ] Rollback plan documented

**Process:**

1. **Initiate Promotion:**
```bash
# Via GitHub UI: Actions → Promote to Production → Run workflow
# Or via CLI:
gh workflow run promote-production.yml \
  -f staging_tag=v1.2.3-rc.4 \
  -f create_release=true
```

2. **Workflow Execution:**
   - Pulls staging RC image
   - Re-tags as production version
   - Pushes production image
   - Updates manifest in PR
   - Creates pull request for review

3. **Review and Approve:**
```bash
# Review the PR
gh pr view <PR-NUMBER>

# Check the changes
git fetch origin
git diff main origin/promote-v1.2.3

# Approve and merge
gh pr review <PR-NUMBER> --approve
gh pr merge <PR-NUMBER> --squash
```

4. **Automatic Deployment:**
   - After PR merge, Flux detects changes
   - Production Kustomization reconciles
   - Backend deployed to `production` namespace
   - GitHub release created (if enabled)

**Monitoring:**
```bash
# Watch production deployment
kubectl get kustomizations -n flux-system | grep production
kubectl rollout status deployment/backend -n production

# Verify health
kubectl get pods -n production -l app=backend
curl https://production.example.com/health

# Check metrics and logs
kubectl logs -n production -l app=backend --tail=100
```

### 4. Rollback Procedures

**Quick Rollback (Deployment level):**
```bash
# Rollback to previous version
kubectl rollout undo deployment/backend -n production

# Rollback to specific revision
kubectl rollout history deployment/backend -n production
kubectl rollout undo deployment/backend -n production --to-revision=2
```

**Full Rollback (GitOps):**
```bash
# Revert the promotion PR
git revert <commit-hash>
git push origin main

# Or manually update to previous version
git checkout -b rollback-v1.2.2
# Edit flux/apps/backend/production/kustomization.yaml
# Change image tag to previous version
git commit -m "chore: rollback backend to v1.2.2"
git push origin rollback-v1.2.2
gh pr create --base main
```

## Flux Operator Components (Gitless GitOps)

This setup uses **Flux Operator's ResourceSet API** instead of traditional ImageUpdateAutomation. Benefits:
- ✅ No Git write-back needed
- ✅ Faster deployment updates
- ✅ Cleaner Git history
- ✅ Direct cluster updates

### ResourceSetInputProvider per Environment

**Development (RC tags):**
```yaml
apiVersion: fluxcd.controlplane.io/v1
kind: ResourceSetInputProvider
metadata:
  name: backend-develop
  namespace: flux-system
spec:
  type: OCIArtifactTag
  url: oci://ghcr.io/ldbl/backend
  filter:
    pattern: '^v[0-9]+\.[0-9]+\.[0-9]+-rc\.[a-f0-9]+$'
    limit: 1
```

**Staging (stable versions):**
```yaml
apiVersion: fluxcd.controlplane.io/v1
kind: ResourceSetInputProvider
metadata:
  name: backend-staging
  namespace: flux-system
spec:
  type: OCIArtifactTag
  url: oci://ghcr.io/ldbl/backend
  filter:
    pattern: '^v[0-9]+\.[0-9]+\.[0-9]+$'
    limit: 1
```

**Production (production-latest tag):**
```yaml
apiVersion: fluxcd.controlplane.io/v1
kind: ResourceSetInputProvider
metadata:
  name: backend-production
  namespace: flux-system
spec:
  type: OCIArtifactTag
  url: oci://ghcr.io/ldbl/backend
  filter:
    includeTag: "production-latest"
    limit: 1
```

### ResourceSet for Auto-Deployment

```yaml
apiVersion: fluxcd.controlplane.io/v1
kind: ResourceSet
metadata:
  name: backend-develop
  namespace: flux-system
spec:
  inputsFrom:
    - kind: ResourceSetInputProvider
      name: backend-develop
  resources:
    - apiVersion: kustomize.toolkit.fluxcd.io/v1
      kind: Kustomization
      metadata:
        name: backend-develop
      spec:
        path: ./flux/apps/backend/develop
        images:
          - name: ghcr.io/ldbl/backend
            newTag: "<< inputs.backend_develop.tag >>"
```

ResourceSet automatically updates the deployment with new images based on the InputProvider filter.

## Directory Structure

```
flux/
├── bootstrap/
│   ├── flux-system/           # Flux core components
│   │   ├── gotk-sync.yaml
│   │   ├── apps.yaml          # Environment kustomizations
│   │   └── image-repository.yaml
│   └── apps/
│       ├── develop/           # Development environment
│       │   ├── backend.yaml   # Kustomization resource
│       │   └── image-policy.yaml
│       ├── staging/           # Staging environment
│       │   ├── backend.yaml
│       │   └── image-policy.yaml
│       └── production/        # Production environment
│           ├── backend.yaml
│           └── image-policy.yaml
└── apps/
    └── backend/
        ├── base/              # Common manifests
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── kustomization.yaml
        ├── develop/           # Development overlay
        │   └── kustomization.yaml
        ├── staging/           # Staging overlay
        │   └── kustomization.yaml
        └── production/        # Production overlay
            └── kustomization.yaml
```

## Release Management

### Semantic Versioning

Follow [semver.org](https://semver.org/) guidelines:
- **MAJOR** version: Incompatible API changes
- **MINOR** version: New functionality (backward compatible)
- **PATCH** version: Bug fixes (backward compatible)

### Creating a New Release

1. **Update version in code** (if applicable)
2. **Merge develop to main** via PR
3. **Wait for staging deployment** and validation
4. **Promote to production** using workflow
5. **Tag is created automatically** by workflow
6. **Update changelog** with release notes

### Changelog Guidelines

Document in `CHANGELOG.md`:
- New features
- Bug fixes
- Breaking changes
- Deprecations
- Security updates

## Troubleshooting

### Flux Not Reconciling

```bash
# Check Flux system health
flux check

# Force reconciliation
flux reconcile kustomization flux-system --with-source

# Check logs
kubectl logs -n flux-system -l app=kustomize-controller --tail=50
```

### Image Not Updating

```bash
# Check ImageRepository
kubectl get imagerepository -n flux-system backend -o yaml

# Check ImagePolicy
kubectl get imagepolicy -n flux-system backend-develop -o yaml

# Force image scan
flux reconcile image repository backend
```

### Deployment Failures

```bash
# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Describe deployment
kubectl describe deployment backend -n <namespace>

# Check pod logs
kubectl logs -n <namespace> -l app=backend --previous
```

## Best Practices

1. **Always test in development first**
2. **Run full test suite in staging**
3. **Never skip staging for production deploys**
4. **Monitor deployments in real-time**
5. **Keep rollback procedure tested and documented**
6. **Use meaningful commit messages** (conventional commits)
7. **Tag releases with detailed notes**
8. **Maintain changelog for all production releases**
9. **Implement automated health checks**
10. **Set up alerts for deployment failures**

## Security Considerations

1. **Container Registry:** Use GitHub Container Registry with proper access controls
2. **Image Scanning:** Enable Dependabot and container scanning
3. **Secrets:** Never commit secrets; use sealed-secrets or external-secrets
4. **RBAC:** Follow principle of least privilege for Flux service accounts
5. **Network Policies:** Implement network segmentation between environments
6. **Audit Logs:** Enable and monitor Kubernetes audit logging

## Additional Resources

- [Flux Documentation](https://fluxcd.io/flux/)
- [FluxCD Image Automation](https://fluxcd.io/flux/guides/image-update/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)

# Lab: Pod Hardening Without Root

## Goal

Validate and maintain hardened runtime settings for backend/frontend:
- non-root user/group
- read-only root filesystem
- no privilege escalation
- dropped capabilities

## Prerequisites

- Flux reconciliation healthy
- backend and frontend deployed in `develop`

Quick checks:

```bash
kubectl -n flux-system get kustomizations
kubectl -n develop get deploy backend frontend
```

## Step 1: Inspect Security Contexts

```bash
kubectl -n develop get deploy backend -o yaml | rg -n "securityContext|runAs|readOnlyRootFilesystem|allowPrivilegeEscalation|capabilities|seccompProfile"
kubectl -n develop get deploy frontend -o yaml | rg -n "securityContext|runAs|readOnlyRootFilesystem|allowPrivilegeEscalation|capabilities|seccompProfile"
```

Expected:
- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- `capabilities.drop: [ALL]`
- `seccompProfile.type: RuntimeDefault`
- `readOnlyRootFilesystem: true`

## Step 2: Verify Runtime Identity

```bash
kubectl -n develop exec deploy/backend -- id
kubectl -n develop exec deploy/frontend -- id
```

Expected:
- non-root UID/GID (10001 in this repo)

## Step 3: Verify Read-Only Root FS Behavior

Write to root path should fail:

```bash
kubectl -n develop exec deploy/backend -- sh -c 'touch /etc/test-write || true'
kubectl -n develop exec deploy/frontend -- sh -c 'touch /etc/test-write || true'
```

Write to allowed tmp/runtime paths should succeed:

```bash
kubectl -n develop exec deploy/backend -- sh -c 'touch /tmp/test-write && ls -l /tmp/test-write'
kubectl -n develop exec deploy/frontend -- sh -c 'touch /tmp/test-write && ls -l /tmp/test-write'
```

## Step 4: Permission-Failure Recovery Drill

Scenario:
- app needs temp/runtime writes
- root FS is read-only

Safe fix path:
1. add explicit volume mount for required writable path
2. keep non-root + no-priv-escalation + dropped caps
3. re-verify runtime behavior

Unsafe shortcut (forbidden):
- setting `runAsUser: 0`
- enabling `privileged: true`
- removing `readOnlyRootFilesystem` without clear requirement

## Rollback

If a hardening change breaks runtime unexpectedly:
1. Revert the specific manifest commit.
2. Let Flux reconcile.
3. Verify deployment readiness and probes.

## Done When

- learner validates hardened settings from manifests and runtime
- learner resolves write-path issue via volumes, not root privileges
- learner can explain blast-radius reduction from these controls

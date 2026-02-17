# Chapter 06: Security Context & Pod Hardening

## Why This Chapter Exists

Container defaults are not production-safe.
This chapter enforces baseline pod hardening:
- non-root execution
- read-only root filesystem where possible
- dropped Linux capabilities
- runtime-default seccomp

## The Incident Hook

A container compromise lands shell access inside a pod.
If the pod runs with broad privileges, escalation is fast.
If security context is hardened, attacker movement is constrained.
This chapter teaches those constraints as default behavior.

## Guardrails

- `runAsNonRoot: true` for pod and container.
- `allowPrivilegeEscalation: false`.
- `capabilities.drop: [ALL]`.
- `seccompProfile: RuntimeDefault`.
- writable paths only via explicit volumes (`/tmp`, runtime/cache dirs).

## Repo Mapping

- Backend deployment: `flux/apps/backend/base/deployment.yaml`
- Frontend deployment: `flux/apps/frontend/base/deployment.yaml`
- Namespace baseline (PSA): `flux/bootstrap/infrastructure/base/namespaces.yaml`

## Current Implementation (This Repo)

- Backend is non-root, read-only root FS, dropped capabilities, seccomp runtime default.
- Frontend is non-root, read-only root FS, dropped capabilities, seccomp runtime default.
- Writable paths are explicitly mounted through `emptyDir` volumes.

## Lab Files

- `lab.md`
- `quiz.md`

## Done When

- learner can prove both workloads run non-root with hardened contexts
- learner can diagnose and fix permission failures without enabling root
- learner can explain why privileged shortcuts are rejected

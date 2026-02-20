# Runbook: Supply Chain Verification (Advanced)

## Purpose

Operate artifact trust controls during deploy and incident response without bypassing safety.

## Scope

This runbook covers:
- signature and attestation verification checks
- Kyverno verify policy behavior (`Audit`/`Enforce`)
- incident triage for untrusted artifact events

## Pre-Deploy Checklist

1. Artifact is immutable (digest or immutable env tag).
2. SBOM/provenance evidence exists.
3. Signature verification succeeds.
4. Policy mode for target namespace is known (`Audit` or `Enforce`).

## Verification Commands

```bash
cosign verify "$IMAGE_REF"
cosign verify-attestation --type spdx "$IMAGE_REF"
kubectl get cpol | rg "verify|attestation"
kubectl get policyreport -A
```

Namespace-level incident evidence:

```bash
kubectl -n <ns> get events --sort-by=.lastTimestamp | tail -n 30
kubectl -n <ns> describe pod <pod-name>
```

## Incident Workflow

1. Freeze promotion of questionable artifact.
2. Validate signature and attestation against policy constraints.
3. If validation fails, rollback to last known trusted digest.
4. Record policy/event evidence in incident timeline.
5. Fix CI signing/provenance path before next promotion.

## Audit to Enforce Strategy

1. Start in `Audit` for `develop`.
2. Review violations for at least one full release cycle.
3. Tighten identity constraints (issuer/subject) as needed.
4. Move selected rules to `Enforce` in `develop`.
5. Promote policy mode gradually to higher environments.

## Failure Modes

1. Missing signature:
- expected: audit/deny depending on mode
- action: fix signing in CI, do not bypass in production

2. Untrusted signer identity:
- expected: audit/deny
- action: align OIDC workflow identity and policy constraints

3. Missing/invalid attestation:
- expected: audit/deny when attestation rule is active
- action: restore SBOM/provenance generation in pipeline

## Break-Glass Rule

Break-glass exception must be:
- time-bound
- scoped to specific workload/environment
- linked to incident or approval record
- removed immediately after remediation

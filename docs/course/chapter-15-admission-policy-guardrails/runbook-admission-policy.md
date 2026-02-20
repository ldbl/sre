# Runbook: Admission Policy Operations (Advanced)

## Purpose

Operate Kyverno guardrails safely while keeping deployment velocity and strong auditability.

## Scope

This runbook covers:
- policy engine health checks
- `Audit` and `Enforce` rollout operations
- deny triage and manifest remediation
- break-glass exception discipline

## Health and Inventory Checks

```bash
kubectl -n kyverno get pods
kubectl get cpol
kubectl get policyreport -A
```

If engine pods are not healthy, pause policy mode changes.

## Operational Policy Modes

- `Audit`: violations are reported but admission is allowed.
- `Enforce`: violating resources are blocked at admission.

Check policy mode:

```bash
kubectl get cpol <policy-name> -o jsonpath='{.spec.validationFailureAction}'; echo
```

Patch policy mode:

```bash
kubectl patch cpol <policy-name> --type merge -p '{"spec":{"validationFailureAction":"Audit"}}'
kubectl patch cpol <policy-name> --type merge -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

## Deny Triage Workflow

1. Capture deny error from `kubectl apply` output.
2. Identify policy and rule from event/report.
3. Confirm whether violation is expected policy behavior.
4. Fix manifest to comply.
5. Re-apply and verify success.

Useful commands:

```bash
kubectl -n <ns> get events --sort-by=.lastTimestamp | tail -n 30
kubectl get policyreport -A | rg <ns>
kubectl describe cpol <policy-name>
```

## Exception Workflow (Break-Glass)

Allowed only when all are true:
- production incident pressure is confirmed
- compliant fix is not immediately available
- exception is minimal, scoped, and time-bound

Mandatory exception fields:
- owner
- reason
- scope (namespace/resource/policy)
- expiry timestamp
- incident or approval reference

After incident:
1. remove exception
2. restore intended policy mode
3. capture preventive follow-up action

## Failure Modes

1. False positives:
- tighten match selectors and conditions
- keep policy intent unchanged

2. Exception sprawl:
- review active exceptions weekly
- auto-expire or delete stale exceptions

3. Silent bypass:
- audit RBAC and cluster-admin usage
- verify no broad wildcard exclusions in policies

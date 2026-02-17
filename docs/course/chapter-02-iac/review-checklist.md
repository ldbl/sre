# Terraform Plan Review Checklist (Guardrails-First)

Use this checklist before any `apply`.

## Change Metadata

- Date:
- Reviewer:
- Terraform target dir:
- Planfile:
- Intended environment:

## 1) Scope Validation

- [ ] Plan affects only intended components.
- [ ] No unrelated resources changed.
- [ ] No hidden cross-environment impact.

Notes:

## 2) Destructive Actions

- [ ] No unexpected `destroy`.
- [ ] If destroy exists, it is intentional and approved.
- [ ] Data-loss impact assessed.

Notes:

## 3) Security and Access

- [ ] Least-privilege credentials used.
- [ ] No plaintext secret values in diff/outputs.
- [ ] State backend and locking are active.

Notes:

## 4) Plan Freshness and Integrity

- [ ] Planfile generated in this review cycle.
- [ ] `tfplan.meta` exists and age is within policy.
- [ ] Apply will use the exact reviewed planfile.

Notes:

## 5) Drift and Dependencies

- [ ] Drift is either absent or explicitly addressed.
- [ ] External dependencies (DNS, secrets, registry, cluster access) validated.
- [ ] Rollback/recovery path documented.

Notes:

## 6) Decision

- [ ] Approved for apply
- [ ] Blocked (requires fixes)

Block reason (if blocked):

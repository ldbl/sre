# Drift Detection Playbook (Chapter 02)

Use this playbook after `terraform plan` to classify drift and choose the right action.

## Fast Drift Check

```bash
terraform -chdir=infra/terraform/hcloud_cluster plan -input=false -detailed-exitcode
echo $?
```

Exit code meaning:
- `0`: no drift / no changes
- `2`: changes detected (drift and/or intended config changes)
- `1`: error (stop and fix tooling/state issues first)

## Drift Classification Matrix

### Class A: Benign Drift

Examples:
- metadata-only fields changed by controllers/providers
- ordering/noise that does not alter behavior

Action:
- document in review notes
- verify no hidden side effects
- proceed if confirmed benign

### Class B: Operational Drift

Examples:
- resource sizing changed outside Terraform
- image/tag or infra parameter changed manually

Action:
- pause apply
- identify source of manual change
- decide: reconcile to Terraform or accept and update Terraform code
- require reviewer sign-off before apply

### Class C: High-Risk Drift

Examples:
- unexpected destroy/recreate of core resources
- network/security boundary changes
- state/backend inconsistencies

Action:
- block apply
- incident-level review
- recovery/rollback plan first, then controlled remediation

## Minimum Evidence to Capture

Before remediation, save:

```bash
terraform -chdir=infra/terraform/hcloud_cluster show tfplan > tfplan.review.txt
```

Attach to PR/review:
- drift class (A/B/C)
- impacted resources
- chosen remediation path
- rollback path

## Safe Remediation Paths

1. Reconcile infra to Terraform
- keep code as source of truth
- apply reviewed plan

2. Accept external change and codify it
- update Terraform to match reality
- plan again
- apply only after clean review

3. Partial or emergency rollback
- isolate high-risk resources
- avoid broad apply/destroy
- re-run plan and checklist after rollback

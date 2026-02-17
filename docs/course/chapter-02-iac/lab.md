# Lab: Safe Terraform Workflow for Production-Like Kubernetes

## Goal

Execute a guardrails-first Terraform workflow:
- plan with explicit output artifact
- review and validate intent
- apply only from reviewed planfile
- verify resulting state

Guardrail companion:
- `review-checklist.md` (must be completed before apply)
- `drift-playbook.md` (required when drift is detected)

## Prerequisites

- Terraform installed
- Access to the target Terraform directory
- Required environment variables/secrets for the selected environment
- `scripts/guard-terraform-plan.sh` available and executable

## Target Options

Choose one:
- Local: `infra/terraform/kind_cluster`
- Hetzner: `infra/terraform/hcloud_cluster`

Examples below use Hetzner path.

## Step 1: Context and Scope Check

Confirm you are in the correct repo and directory:

```bash
pwd
ls -la
```

Expected:
- path ends with `sre/`
- Terraform target directory exists

## Step 2: Generate a Planfile (Guarded)

```bash
scripts/guard-terraform-plan.sh plan \
  --dir infra/terraform/hcloud_cluster \
  --out tfplan
```

Expected output includes:
- `plan created: .../tfplan`
- `metadata created: .../tfplan.meta`

## Step 3: Review Plan Before Apply

```bash
terraform -chdir=infra/terraform/hcloud_cluster show tfplan
```

Now complete `review-checklist.md` and attach it to PR/review notes.

Hard stop conditions (do not apply):
- Any unexpected `destroy` action.
- Changes to unrelated modules/resources.
- Environment mismatch (wrong account/cluster/namespace assumptions).
- Planfile older than policy window for this change.

## Step 4: Apply Only the Reviewed Planfile

```bash
scripts/guard-terraform-plan.sh apply \
  --dir infra/terraform/hcloud_cluster \
  --out tfplan \
  --max-age-minutes 60
```

Expected:
- Apply runs only if `tfplan` and `tfplan.meta` are present and fresh.
- If stale/missing metadata, script blocks apply with explicit error.
- Apply must happen only after signed-off checklist completion.

## Step 5: Verify Post-Apply State

```bash
terraform -chdir=infra/terraform/hcloud_cluster output
```

For cluster targets, also verify:

```bash
kubectl get nodes
kubectl get ns
```

## Step 6: Drift Detection Drill

Run a fresh plan after apply:

```bash
terraform -chdir=infra/terraform/hcloud_cluster plan -input=false -detailed-exitcode
echo $?
```

Expected:
- `0`: no changes, continue
- `2`: drift and/or pending changes, classify using `drift-playbook.md`
- `1`: tooling/state error, stop and fix before any apply

Stop criteria by drift class (from `drift-playbook.md`):
- Class A: document evidence and proceed only after reviewer confirms benign impact.
- Class B: pause apply, decide reconcile-vs-codify path, then re-plan.
- Class C: block apply and escalate to incident-level review.

## Step 7: Safe Destroy Practice (Dry Run Discussion)

Do not run destroy blindly. First define:
- exact target environment
- expected deleted resource classes
- recreate path and recovery time expectation

Optional (only in isolated test env):

```bash
terraform -chdir=infra/terraform/hcloud_cluster plan -destroy -input=false
```

Destroy preflight checklist (required):
- Correct target environment confirmed.
- Data/state impact explicitly documented.
- Recreate path documented and tested at least once in non-prod.
- Stakeholder approval recorded.
- Scope is explicit (`-target` or clearly bounded module/resource set) and reviewed.

## Failure Scenarios

1. Apply without plan metadata
- command should fail
- learner explains why guardrail blocked execution

2. Stale planfile
- command should fail when `--max-age-minutes` is exceeded
- learner regenerates plan and re-runs review

## Done When

- Learner can run guarded `plan -> apply` end-to-end.
- Learner can explain why lock/state/plan artifacts reduce blast radius.
- Learner can identify and communicate drift before applying new changes.
- Learner can use and defend a concrete plan review checklist before any apply.

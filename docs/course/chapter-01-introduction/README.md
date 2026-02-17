# Chapter 01: AI Changes Two Things at Once

## Incident Hook

A fast "AI-assisted" hotfix bundles two unrelated changes in one push:
- a backend image tag bump for `develop`
- an ingress manifest change intended for `staging`

The change looks harmless in review because each diff is small. In practice, the combined blast radius is larger: routing breaks while backend behavior changes at the same time, making rollback and triage slower.

## What AI Would Propose (Brave Junior)

- "Update image and ingress together to save one pipeline run."
- "Apply quickly to unblock the demo."
- "Skip context checks; it is just `develop`."

Why it sounds reasonable:
- fewer PRs
- faster merge
- faster "visible progress"

## Why This Is Dangerous

- Missing context: target cluster/namespace is often assumed, not verified.
- Hidden coupling: app rollout + ingress mutation creates correlated failure modes.
- Production risk pattern: the same behavior scales into high-blast-radius incidents.

## Guardrails That Stop It

- Context guard before any Kubernetes write:
  - `scripts/guard-kube-context.sh --context <ctx> --namespace <ns>`
- Plan-before-apply guard for Terraform:
  - `scripts/guard-terraform-plan.sh plan ...`
  - `scripts/guard-terraform-plan.sh apply ...`
- Single-change policy:
  - one PR for image/promotion
  - separate PR for networking/ingress

## Safe Workflow (Step-by-Step)

1. Verify context and namespace.
2. Produce plan/diff first (Terraform or GitOps diff).
3. Review for correlated changes.
4. Apply one change type at a time.
5. Verify health and routing separately.
6. Keep rollback commands prepared before merge/apply.

## Demo Commands

### A. Kubernetes context/namespace guard

```bash
# Expected success example
scripts/guard-kube-context.sh \
  --context sre-control-plane \
  --namespace develop
```

Expected output:
```text
[guard-kube] OK context=sre-control-plane namespace=develop
```

Failure example (wrong namespace):
```bash
scripts/guard-kube-context.sh \
  --context sre-control-plane \
  --namespace does-not-exist
```

Expected output:
```text
[guard-kube] namespace 'does-not-exist' not found in context 'sre-control-plane'
```

### B. Terraform plan-before-apply guard

```bash
# Create plan + metadata marker
scripts/guard-terraform-plan.sh plan \
  --dir infra/terraform/hcloud_cluster \
  --out tfplan

# Apply only from a fresh, reviewed planfile
scripts/guard-terraform-plan.sh apply \
  --dir infra/terraform/hcloud_cluster \
  --out tfplan \
  --max-age-minutes 60
```

If plan marker is missing/stale, apply is blocked with an explicit error.

## Rollback Checklist

1. If Kubernetes deploy changed:
   - `kubectl -n <ns> rollout undo deployment/<name>`
2. If ingress changed:
   - revert ingress commit in Git and let Flux reconcile
3. If Terraform apply changed infra:
   - create a new reviewed plan and apply rollback change
4. Verify:
   - `/healthz` on backend
   - ingress route with Host header

## Exercises

1. Split a mixed PR into two PRs:
   - PR1: image tag update only
   - PR2: ingress update only
2. Intentionally run `guard-terraform-plan.sh apply` without a planfile and capture the failure output.

## Done When

- Student can explain why "small but mixed" changes are high risk.
- Student can demonstrate both guard scripts before any apply action.

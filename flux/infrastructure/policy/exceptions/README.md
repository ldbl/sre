# Policy Exceptions

A Kyverno `PolicyException` (`policies.kyverno.io/v1`) lets one named workload past one policy -
everything else stays under the guardrail. This directory is the only way one reaches the cluster:

- Kyverno reads exceptions only from the `policy-exceptions` namespace
  (`features.policyExceptions` in `../kyverno/release.yaml`).
- `only-from-git.yaml` (a native ValidatingAdmissionPolicy) lets only Flux's kustomize-controller
  create or change them - `kubectl apply` is refused, cluster-admin included.
- Kyverno stops applying an exception at its `spec.expiresAt`.
- `scripts/check-policy-exceptions.sh` (pre-commit and CI) requires on each one:
  - `metadata.namespace: policy-exceptions`;
  - the annotations `safeops.io/owner` and `safeops.io/reason` (a link to the issue or incident);
  - `spec.expiresAt` (`2026-12-31T00:00:00Z`, UTC), in the future and at most 90 days ahead;
  - one `policyRefs` entry naming a policy that exists in `../packs/` - for a guardrail, the copy
    that judges the namespace (`<name>-enforce` for `develop`/`staging`/`production`);
  - one `matchConditions` entry in this form, and nothing else in `spec`:
    ```
    object.metadata.namespace == 'develop' && object.metadata.name == 'vendor-agent'
    object.metadata.namespace == 'develop' && object.metadata.name.startsWith('vendor-agent')
    ```
    One literal namespace and one workload. The prefix form covers a Deployment and its pods
    (`vendor-agent-<hash>-<id>`). CEL could say anything; the fixed form keeps the exception
    reviewable - no exception for a whole namespace, by label, or for the whole cluster.
  It also fails every pull request once an exception has expired, until it is removed or renewed
  on purpose.

## Add one

1. Create `<namespace>-<name>.yaml` here (template: `tests/kyverno/exceptions.yaml`) and list it in
   `kustomization.yaml`.
2. Open a pull request; the checks run; merge; Flux applies it within its interval
   (on kind, to not wait: `flux --context kind-sre-control-plane reconcile kustomization policy-exceptions --with-source`).
3. Remove it the same way when the reason is gone - at the latest on its expiry date.

Chapter 16 walks through it.

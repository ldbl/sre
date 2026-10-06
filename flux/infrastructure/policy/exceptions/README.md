# Policy Exceptions

A Kyverno `PolicyException` lets one named resource past one rule of one policy - everything else
stays under the guardrail. This directory is the only way one reaches the cluster:

- Kyverno reads exceptions only from the `policy-exceptions` namespace
  (`features.policyExceptions` in `../kyverno/release.yaml`).
- `only-from-git.yaml` (a native ValidatingAdmissionPolicy) lets only Flux's kustomize-controller
  create or change them - `kubectl apply` is refused, cluster-admin included.
- `scripts/check-policy-exceptions.sh` (pre-commit and CI) requires on each one:
  - `metadata.namespace: policy-exceptions`;
  - the annotations `safeops.io/owner`, `safeops.io/reason` (a link to the issue or incident) and
    `safeops.io/expires` (`YYYY-MM-DD`, at most 90 days ahead);
  - one policy and one rule (`ruleNames` may add its `autogen-<rule>` variants, which a Deployment
    needs), no `*`;
  - one namespace and at least one resource name in every `match` entry - no exception for a whole
    namespace or the whole cluster.
  It also fails every pull request once an exception has expired, until it is removed or renewed
  on purpose.

## Add one

1. Create `<namespace>-<name>.yaml` here (template: `tests/kyverno/exceptions.yaml`) and list it in
   `kustomization.yaml`.
2. Open a pull request; the checks run; merge; Flux applies it within its interval
   (on kind, to not wait: `flux --context kind-sre-control-plane reconcile kustomization policy-exceptions --with-source`).
3. Remove it the same way when the reason is gone - at the latest on its expiry date.

Chapter 16 walks through it.

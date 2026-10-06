# Policy Packs

Each pack is one Flux Kustomization (`flux/bootstrap/flux-system/infrastructure.yaml`), applied after
the `kyverno` engine. `${image_registry}` and `${git_owner}` come from the `cluster-config` ConfigMap
(Flux postBuild substitution).

- `admission-guardrails/` - Chapter 16. Enforce in the application namespaces, Audit elsewhere.
- `supply-chain/` - Chapter 17. Audit.

Rollout, for any new rule: Audit everywhere first; read the PolicyReports until the namespaces it will
enforce in have no failures (and the workloads created only now and then - lab pods, Jobs - are
checked too); then add the Enforce override for those namespaces, in a pull request with that
evidence.

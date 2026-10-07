# Policy Infrastructure (Kyverno)

| Directory | Flux Kustomization | What it holds |
|---|---|---|
| `kyverno/` | `kyverno` | the engine (HelmRelease): admission webhooks, background scans, PolicyReports; PolicyExceptions read only from `policy-exceptions` |
| `packs/admission-guardrails/` | `policy-admission-guardrails` | five ClusterPolicies - Enforce in `develop`/`staging`/`production`, Audit elsewhere (Chapter 16) |
| `packs/supply-chain/` | `policy-supply-chain` | an ImageValidatingPolicy: our images signed by their own CI, with an SBOM - Deny in `develop`/`staging`/`production`, Audit elsewhere (Chapter 17) |
| `exceptions/` | `policy-exceptions` | the `policy-exceptions` namespace, the guard that lets only Flux write exceptions, and the exceptions (Chapter 16) |

Everything here reaches the cluster only through Git - a policy's mode, its scope and every exception.

Two other admission policies are native ValidatingAdmissionPolicies, not Kyverno: they guard the access
model and must not depend on an engine that can be down - `oidc-flux-operator-fields`
(`../security/rbac/`) and `chaos-monkey-targets` (`../chaos/develop/`), plus
`policy-exceptions-only-from-git` (`exceptions/`).

Failure mode: Kyverno's webhooks fail closed. While no Kyverno replica answers, the API server refuses
new Pods in every namespace the webhooks cover (all but `kube-system`, `flux-system` and `kyverno`).
Two replicas and a PodDisruptionBudget keep one answering through a node drain; `flux-system` is
excluded so that Flux can always repair Kyverno.

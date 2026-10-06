# Policy Pack: Admission Guardrails (Chapter 16)

| Policy | Rule | Refuses |
|---|---|---|
| `disallow-latest-tag` | `no-latest` | an image tagged `latest` or not tagged at all |
| `require-trusted-registries` | `trusted-registries-only` | an image not from `${image_registry}`, CloudNativePG or the lab images |
| `disallow-privileged-containers` | `no-privileged` | `privileged: true`, init containers included |
| `require-security-context` | `require-container-security-context` | a container that may run as root or escalate privileges |
| `require-requests-limits` | `require-cpu-memory-requests-limits` | a container without CPU and memory requests and limits |

Mode, per rule: `failureAction: Audit` (a PolicyReport entry) with a `failureActionOverrides` entry
that sets `Enforce` (the API server refuses the request) for `develop`, `staging` and `production`.
Kyverno also generates each rule for the pod controllers (`autogen-<rule>`): a Deployment that breaks
a rule is refused at `apply`, not later when its pods are created.

The platform namespaces stay in Audit: their charts break several rules today (see the PolicyReports),
and fixing those charts is its own work. An exception for one workload goes in
`../../exceptions/`, through a pull request.

Tests: `tests/kyverno-policies.test.sh` (pre-commit and CI) checks the expected verdict of every rule
against `tests/kyverno/resources.yaml`, and that every policy in this pack has expected verdicts.

# Policy Pack: Admission Guardrails (Chapter 16)

| File | Refuses |
|---|---|
| `disallow-latest-tag.yaml` | an image tagged `latest` or not tagged at all (no digest) |
| `require-trusted-registries.yaml` | an image not from `${image_registry}`, CloudNativePG or the lab images |
| `disallow-privileged-containers.yaml` | `privileged: true`, init containers included |
| `require-security-context.yaml` | a container that may run as root or escalate privileges |
| `require-requests-limits.yaml` | a container without CPU and memory requests and limits |

Each file is one guardrail as two Kyverno `ValidatingPolicy` objects (CEL, `policies.kyverno.io/v1`):

- `<name>-enforce` - `validationActions: [Deny]`, `failurePolicy: Fail`, namespaces `develop`, `staging`,
  `production`: the API server refuses the request; while Kyverno cannot answer, it refuses too.
- `<name>-audit` - `validationActions: [Audit]`, `failurePolicy: Ignore`, every other namespace: a
  PolicyReport entry, and nothing blocked when Kyverno is down.

A ValidatingPolicy has one action for all the namespaces it matches - there is no per-namespace
override, as ClusterPolicy's `failureActionOverrides` was - so the namespaces are split by the
`namespaceSelector` (`In` / `NotIn`). The two copies are identical otherwise;
`tests/kyverno-policies.test.sh` fails when they drift apart.

What is matched: Pods (and `pods/ephemeralcontainers`, which `kubectl debug` writes) and the
controllers that create them - Deployments, StatefulSets, DaemonSets, Jobs, CronJobs - listed in
`matchConstraints`, with a `podSpec` variable that finds the pod template in each. Kyverno's autogen
would generate the controller variants itself, but only for a policy that matches `pods` alone - not
with the ephemeral containers subresource (Kyverno 1.19, `pkg/cel/autogen/support.go`). Listed, they
are also visible: a Deployment that breaks a guardrail is refused at `apply`, not later when its pods
are created.

The platform namespaces stay in Audit: their charts break several rules today (see the PolicyReports),
and fixing those charts is its own work. An exception for one workload goes in
`../../exceptions/`, through a pull request.

Tests: `tests/kyverno-policies.test.sh` (pre-commit and CI) checks the expected verdict of every policy
against `tests/kyverno/resources.yaml`, that each copy has an expected pass and fail, and the pairs.

# Policy Pack: Supply Chain (Chapter 17)

One Kyverno `ImageValidatingPolicy` in two copies (`verify-images-enforce.yaml`, `verify-images-audit.yaml`):
every image from `${image_registry}` must be

- **signed** - keyless cosign, by `build.yml` of its own repository (`backend`, `frontend`,
  `k8s-ai-monitor`) on `main` or `develop`, and
- **with an SPDX SBOM attestation** signed the same way.

| Copy | Namespaces | Action | failurePolicy |
|---|---|---|---|
| `verify-images-enforce` | `develop`, `staging`, `production` | Deny | Fail |
| `verify-images-audit` | every other namespace (`observability`: the Guardian) | Audit (PolicyReports) | Ignore |

Images from other registries are ignored here; Chapter 16's `require-trusted-registries` decides
whether they may run. Init and ephemeral containers are checked too.

Why an ImageValidatingPolicy: the CI signs with cosign v3 - Sigstore bundles stored as OCI referrers.
ClusterPolicy `verifyImages` finds none of them; the ImageValidatingPolicy verifies the bundles and the
older `.sig` format. An image whose signature and SBOM are in the old format while GitHub's provenance
is a referrer fails the SBOM check: with a referrer present, only the referrers are read.

The pod runs what was verified: Kyverno resolves the tag, verifies that digest and writes it into the
image (`mutateDigest`), so the cluster shows `<tag>@sha256:...` while Git keeps the tag.

Admission needs Kyverno to reach ghcr.io and Sigstore. In the application namespaces a failed lookup
refuses the pod (fail closed); elsewhere it is ignored.

Tests: `tests/kyverno-supply-chain.test.sh` (pre-commit and CI; needs the network) - real images pinned
by digest: signed in both formats, unsigned, mixed formats, a foreign sidecar, an unsigned init
container; and the two copies must not drift apart. `labs/supply-chain/unsigned-demo` is the lab's
unsigned image.

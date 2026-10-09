# Policy Pack: Supply Chain (Chapter 17)

One Kyverno `ImageValidatingPolicy` in two copies (`verify-images-enforce.yaml`, `verify-images-audit.yaml`):
every image from `${image_registry}` must be

- **signed** - keyless cosign, by `build.yml` of the repository it is named after, on `main` or
  `develop`: a `backend` image by backend's workflow, `frontend` by frontend's, `k8s-ai-monitor` by
  the Guardian's. One attestor per repository and a `signers` map in the policy; an image of any other
  repository in the registry has no signer and is refused (`unsigned-demo`). The test proves the
  mapping by remapping backend images to the frontend's signer: the real backend image must fail.
- **with an SPDX SBOM attestation** signed by the same repository's workflow.

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

Tags are verified as they resolve at admission. Pinning the verified digest into the pod (`mutateDigest`)
needs Kyverno 1.19 - 1.17 does not implement it for ImageValidatingPolicy - so a tag moved between
admission and the pull is accepted tech debt until that upgrade.

Verification costs about ten seconds uncached per webhook call (ghcr.io, Sigstore); the webhooks get
the maximum timeout, 30 s.

Verification runs at admission only (`evaluation.background.enabled: false`). A background scan
re-verified every running pod's images on every resync; on kind it kept the reports controller at
1.3 cores on average (6.6 at peak), it lost its leader lease under that load and restarted 49 times in
29 hours, starting the scan over each time. A running pod's image does not change, so the re-check
bought nothing. The cost: a pod admitted while Kyverno could not answer (the audit copy fails open)
has no report until it is recreated.

Admission needs Kyverno to reach ghcr.io and Sigstore. In the application namespaces a failed lookup
refuses the pod (fail closed); elsewhere it is ignored.

Tests: `tests/kyverno-supply-chain.test.sh` (pre-commit and CI; needs the network) - real images pinned
by digest: signed in both formats, unsigned, mixed formats, a foreign sidecar, an unsigned init
container; and the two copies must not drift apart. `labs/supply-chain/unsigned-demo` is the lab's
unsigned image.

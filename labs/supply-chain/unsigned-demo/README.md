# unsigned-demo (Chapter 17)

`ghcr.io/safeops-course/unsigned-demo:1.0` - busybox, built by CI and pushed **without** a cosign
signature, an SBOM attestation or build provenance. It exists to be refused:

- In `develop`, `staging` and `production` the supply-chain policy refuses it at admission.
- Elsewhere it is admitted and the PolicyReport records the failure.
- `tests/kyverno-supply-chain.test.sh` uses it as the negative case next to the signed backend and
  frontend images.

Built by `.github/workflows/unsigned-demo.yml` (manual run, or a change to this directory on `main`).
Never sign it: a signed copy would turn the negative case into a positive one silently - the test
would fail, which is how you would find out.

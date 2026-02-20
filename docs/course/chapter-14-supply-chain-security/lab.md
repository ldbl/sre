# Lab: Signed Artifacts and Verification Policy Rollout (Advanced)

## Goal

Run a complete non-production supply-chain flow:
- produce SBOM evidence for one artifact
- sign and attest the artifact
- validate evidence with `cosign verify*`
- test verification policy in `Audit`, then `Enforce`

## Prerequisites

- `cosign` and `syft` installed
- access to a test image in your registry
- access to `develop` namespace
- Kyverno engine running
- starter policy templates available:
  - `flux/infrastructure/policy/packs/chapter-14-supply-chain/verify-images.example.yaml`
  - `flux/infrastructure/policy/packs/chapter-14-supply-chain/verify-attestations.example.yaml`

Quick checks:

```bash
command -v cosign
command -v syft
kubectl -n kyverno get pods
kubectl get ns develop
```

## Step 1: Select Immutable Artifact

Use digest form whenever possible:

```bash
export IMAGE_REF="ghcr.io/<org>/<app>@sha256:<digest>"
echo "$IMAGE_REF"
```

Hard stop:
- do not use mutable `:latest` for this lab.

## Step 2: Generate SBOM and Sign/Attest

```bash
syft "$IMAGE_REF" -o spdx-json > sbom.spdx.json
cosign sign --yes "$IMAGE_REF"
cosign attest --yes --predicate sbom.spdx.json --type spdx "$IMAGE_REF"
```

## Step 3: Verify Artifact Evidence

```bash
cosign verify "$IMAGE_REF"
cosign verify-attestation --type spdx "$IMAGE_REF"
```

Capture command output as lab evidence.

## Step 4: Apply Chapter 14 Policies in Audit Mode

Use template policies as baseline (keep `validationFailureAction: Audit`):

```bash
kubectl apply -f flux/infrastructure/policy/packs/chapter-14-supply-chain/verify-images.example.yaml
kubectl apply -f flux/infrastructure/policy/packs/chapter-14-supply-chain/verify-attestations.example.yaml
kubectl get cpol | rg "verify|attestation"
```

## Step 5: Trigger Audit Events

Apply one workload with untrusted/unsigned artifact (expected audit signal), then one trusted artifact.

```bash
kubectl -n develop apply -f <unsigned-or-untrusted-workload>.yaml
kubectl -n develop apply -f <trusted-workload>.yaml
```

Inspect reports/events:

```bash
kubectl -n develop get events --sort-by=.lastTimestamp | tail -n 30
kubectl get policyreport -A | rg develop
```

## Step 6: Promote One Policy to Enforce

Switch one policy to Enforce in non-production only:

```bash
kubectl patch cpol verify-signed-images-example \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

Re-apply untrusted workload and confirm deny.

## Step 7: Roll Back to Audit (Cleanup)

```bash
kubectl patch cpol verify-signed-images-example \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'
```

Optional cleanup:

```bash
kubectl delete cpol verify-signed-images-example require-sbom-attestation-example --ignore-not-found=true
rm -f sbom.spdx.json
```

## Evidence to Capture

- immutable image reference used
- `cosign verify` summary
- `cosign verify-attestation` summary
- policyreport/event line for failed verification
- deny output after `Enforce` change

## Hard Stop Conditions

- disabling verification policy globally to unblock release
- enforcing in production before stable audit data in non-production
- rebuilding production artifact instead of promoting verified artifact

## Done When

- learner demonstrates `Audit -> Enforce -> Audit` rollout safely
- learner can explain deny reason and remediation path

#!/usr/bin/env bash
# Tests the supply-chain policies (flux/infrastructure/policy/packs/supply-chain) with the Kyverno CLI
# against real images - pinned by digest in tests/kyverno-supply-chain/resources.yaml: a backend image
# (cosign v3 bundle), a frontend image (cosign v2 .sig), an unsigned image. Needs the network: Kyverno
# reads the signatures from ghcr.io and checks them against Sigstore's public trust root.
#
# Also checks that verify-images-enforce is Deny/Fail/In and verify-images-audit Audit/Ignore/NotIn, and
# that otherwise the two copies are identical - a fix made in one copy only fails here.
# The verdicts are the engine's (pass/fail); that Deny actually refuses at admission is the kind lab's job.
#
# ${image_registry} and ${git_owner} are filled in the way Flux does (postBuild, cluster-config).
# Kyverno CLI >= 1.19, as tests/kyverno-policies.test.sh (1.17 marks these results "Excluded").
#
# Run: tests/kyverno-supply-chain.test.sh   (pre-commit runs it when the policies or this test change)
# Needs: kyverno (CLI), yq (v4), the network. Read-only. Exit 0 when every verdict holds, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="${ROOT}/flux/infrastructure/policy/packs/supply-chain"
IMAGE_REGISTRY="ghcr.io/safeops-course"   # cluster-config: image_registry
GIT_OWNER="safeops-course"                # cluster-config: git_owner
MIN_KYVERNO="1.19"

command -v kyverno >/dev/null || { echo "kyverno-supply-chain: the kyverno CLI is required (make check-tools)" >&2; exit 1; }
command -v yq >/dev/null || { echo "kyverno-supply-chain: yq is required (make check-tools)" >&2; exit 1; }
version="$(kyverno version 2>/dev/null | sed -n 's/^Version: v\{0,1\}\([0-9][0-9.]*\).*/\1/p')"
if [[ "$(printf '%s\n%s\n' "${MIN_KYVERNO}" "${version:-0}" | sort -V | head -1)" != "${MIN_KYVERNO}" ]]; then
  echo "kyverno-supply-chain: kyverno CLI ${version:-unknown} is too old, need >= ${MIN_KYVERNO}" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/policies"
cp "${ROOT}"/tests/kyverno-supply-chain/{kyverno-test.yaml,resources.yaml,values.yaml} "${WORK}/"

# Each copy has exactly its own action and failure policy - checked before they are stripped below.
check_mode() {
  local file="$1" action="$2" failure="$3" operator="$4" got
  got="$(yq '[.spec.validationActions | join(","), .spec.failurePolicy, .spec.matchConstraints.namespaceSelector.matchExpressions[0].operator] | join(" ")' "${PACK}/${file}")"
  if [[ "${got}" != "${action} ${failure} ${operator}" ]]; then
    echo "kyverno-supply-chain: ${file}: expected '${action} ${failure} ${operator}' (actions, failurePolicy, namespace operator), got '${got}'" >&2
    exit 1
  fi
}
check_mode verify-images-enforce.yaml Deny Fail In
check_mode verify-images-audit.yaml Audit Ignore NotIn

# Settings both copies must have - checked per file, not only through the parity check below:
# a 30 s webhook timeout (an uncached verification takes seconds), the verified digest pinned into
# the pod (mutateDigest - Kyverno >= 1.19; verifyDigest stays off until the mutation is seen on kind -
# this CLI validates without mutating, so it cannot show it) and no background scan (it
# re-verified every running image on every resync and kept the reports controller at several
# cores); see the policy header.
for file in verify-images-enforce.yaml verify-images-audit.yaml; do
  got="$(yq '[.spec.validationConfigurations.mutateDigest, .spec.validationConfigurations.verifyDigest, .spec.webhookConfiguration.timeoutSeconds, .spec.evaluation.background.enabled] | join(" ")' "${PACK}/${file}")"
  if [[ "${got}" != "true false 30 false" ]]; then
    echo "kyverno-supply-chain: ${file}: expected 'true false 30 false' (mutateDigest, verifyDigest, timeoutSeconds, background), got '${got}'" >&2
    exit 1
  fi
done

# The two copies must not drift: drop what may differ, compare the rest.
strip='del(.metadata.name) | del(.metadata.annotations["policies.kyverno.io/title"])
  | del(.spec.validationActions) | del(.spec.failurePolicy)
  | del(.spec.matchConstraints.namespaceSelector.matchExpressions[0].operator)'
if ! diff <(yq "${strip}" "${PACK}/verify-images-enforce.yaml") <(yq "${strip}" "${PACK}/verify-images-audit.yaml") >&2; then
  echo "kyverno-supply-chain: verify-images-enforce.yaml and verify-images-audit.yaml differ beyond name, title, action, failurePolicy and namespace operator" >&2
  exit 1
fi

# Every policy the pack lists, with the Flux variables filled in.
while IFS= read -r policy; do
  sed -e "s|\${image_registry}|${IMAGE_REGISTRY}|g" -e "s|\${git_owner}|${GIT_OWNER}|g" \
    "${PACK}/${policy}" > "${WORK}/policies/${policy}"
done < <(yq '.resources[]' "${PACK}/kustomization.yaml")

kyverno test "${WORK}" --remove-color

# Each image is verified against the signer of its own repository, not against "any of ours". No
# real image is signed by another repository's workflow (GHCR lets a repository push only to its own
# package), so the proof swaps the mapping instead: with backend images mapped to the frontend's
# signer, the real backend image must fail and the others must still pass. The swap edits the
# policy's `signers` map; if the policy no longer has it - back to one identity for all images, or
# a list of all three signers per image - the swap changes nothing and the check fails loudly.
SWAP="$(mktemp -d)"
trap 'rm -rf "${WORK}" "${SWAP}"' EXIT
mkdir -p "${SWAP}/policies"
cp "${WORK}/resources.yaml" "${WORK}/values.yaml" "${SWAP}/"
sed "s|'backend': attestors.backend|'backend': attestors.frontend|" "${WORK}/policies/verify-images-enforce.yaml" \
  > "${SWAP}/policies/verify-images-enforce.yaml"
if cmp -s "${WORK}/policies/verify-images-enforce.yaml" "${SWAP}/policies/verify-images-enforce.yaml"; then
  echo "kyverno-supply-chain: the policy has no per-repository signer map ('backend': attestors.backend) - each image must be verified against its own repository's signer" >&2
  exit 1
fi
cat > "${SWAP}/kyverno-test.yaml" <<'TEST'
apiVersion: cli.kyverno.io/v1alpha1
kind: Test
metadata:
  name: supply-chain-swapped-signers
policies:
  - policies/verify-images-enforce.yaml
resources:
  - resources.yaml
variables: values.yaml
results:
  - {policy: verify-images-enforce, kind: Pod, resources: [backend-signed], result: fail}
  - {policy: verify-images-enforce, kind: Pod, resources: [frontend-signed-legacy-format, guardian-signed], result: pass}
TEST
echo "kyverno-supply-chain: backend images mapped to the frontend's signer: the backend image must fail"
kyverno test "${SWAP}" --remove-color

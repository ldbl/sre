#!/usr/bin/env bash
# Tests the supply-chain policies (flux/infrastructure/policy/packs/supply-chain) with the Kyverno CLI
# against real images - pinned by digest in tests/kyverno-supply-chain/resources.yaml: a backend image
# (cosign v3 bundle), a frontend image (cosign v2 .sig), an unsigned image. Needs the network: Kyverno
# reads the signatures from ghcr.io and checks them against Sigstore's public trust root.
#
# Also checks that the two copies of the policy (enforce, audit) are identical but for their name,
# title, action, failure policy and namespace operator - a fix made in one copy only fails here.
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

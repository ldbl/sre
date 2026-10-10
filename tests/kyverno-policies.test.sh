#!/usr/bin/env bash
# Tests the admission guardrails (flux/infrastructure/policy/packs/admission-guardrails) with the
# Kyverno CLI - no cluster. tests/kyverno/kyverno-test.yaml lists the expected verdict for every case
# in tests/kyverno/resources.yaml (pass / fail / skip by tests/kyverno/exceptions.yaml).
#
# The policies hold ${image_registry}, which Flux fills in from the cluster-config ConfigMap
# (postBuild). This test fills it the same way, with the platform's registry, into a throw-away copy.
#
# Kyverno CLI >= 1.19: 1.17 reports a wrong expectation ("Want fail, got pass") but still counts it
# as passed and exits 0 when the test loads exceptions - a test that cannot fail. The cluster runs
# Kyverno 1.19 (chart 3.9.1) - the same engine as this test.
#
# Run: tests/kyverno-policies.test.sh   (pre-commit runs it when a policy or this test changes)
# Needs: kyverno (CLI). Read-only: changes no file in the repository and no cluster.
# Exit 0 when every expected verdict holds, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="${ROOT}/flux/infrastructure/policy/packs/admission-guardrails"
IMAGE_REGISTRY="ghcr.io/safeops-course"   # the value of image_registry in cluster-config
MIN_KYVERNO="1.19"

command -v kyverno >/dev/null || { echo "kyverno-policies: the kyverno CLI is required (make check-tools)" >&2; exit 1; }
version="$(kyverno version 2>/dev/null | sed -n 's/^Version: v\{0,1\}\([0-9][0-9.]*\).*/\1/p')"
if [[ "$(printf '%s\n%s\n' "${MIN_KYVERNO}" "${version:-0}" | sort -V | head -1)" != "${MIN_KYVERNO}" ]]; then
  echo "kyverno-policies: kyverno CLI ${version:-unknown} is too old, need >= ${MIN_KYVERNO} (see the header)" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
mkdir -p "${WORK}/policies"
cp "${ROOT}"/tests/kyverno/{kyverno-test.yaml,resources.yaml,exceptions.yaml} "${WORK}/"

# Every policy the pack's kustomization.yaml lists, with ${image_registry} filled in. Listed, not
# globbed: a policy file that Flux does not apply must not pass here either.
while IFS= read -r policy; do
  sed "s|\${image_registry}|${IMAGE_REGISTRY}|g" "${PACK}/${policy}" > "${WORK}/policies/${policy}"
done < <(yq '.resources[]' "${PACK}/kustomization.yaml")

# Every policy in the pack must be in the test.
for policy in "${WORK}"/policies/*.yaml; do
  rel="policies/$(basename "${policy}")"
  if [[ "$(yq ".policies | contains([\"${rel}\"])" "${WORK}/kyverno-test.yaml")" != "true" ]]; then
    echo "kyverno-policies: ${rel} is in the pack but not in tests/kyverno/kyverno-test.yaml" >&2
    exit 1
  fi
done

# Every rule of every policy must have at least one expected pass and one expected fail: a rule
# tested only one way could be broken the other way - refusing everything, or nothing - and pass.
# A rule's autogen-<rule> variant (pod controllers) counts as the same rule.
for policy in "${WORK}"/policies/*.yaml; do
  name="$(yq '.metadata.name' "${policy}")"
  # Captured first, not read from a process substitution: a failing yq stops the script here (set -e),
  # and a policy with no rules is an error, not a loop that checks nothing.
  rules="$(yq '.spec.rules[].name' "${policy}")"
  if [[ -z "${rules}" ]]; then
    echo "kyverno-policies: ${name} has no rules (.spec.rules[].name is empty)" >&2
    exit 1
  fi
  while IFS= read -r rule; do
    for verdict in pass fail; do
      found="$(yq "[.results[] | select(.policy == \"${name}\" and (.rule == \"${rule}\" or .rule == \"autogen-${rule}\") and .result == \"${verdict}\")] | length" "${WORK}/kyverno-test.yaml")"
      if [[ "${found}" == "0" ]]; then
        echo "kyverno-policies: ${name}/${rule} has no expected '${verdict}' in tests/kyverno/kyverno-test.yaml" >&2
        exit 1
      fi
    done
  done <<<"${rules}"
done

kyverno test "${WORK}" --remove-color

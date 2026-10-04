#!/usr/bin/env bash
# Tests scripts/check-image-tags.sh on a throw-away copy of flux/apps - no cluster, no registry.
# Run: tests/check-image-tags.test.sh   (pre-commit runs it when the check or this test changes)
# Each case breaks one line of the production backend overlay in a fresh copy, runs the check and
# compares the verdict (pass/fail) with the expected one. Needs yq (v4), like the check.
# Exit 0 when every case passes, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# fresh_copy - a new copy of the check and of flux/apps in WORK/repo; the check finds the repository
# from its own location, so it reads the copy.
fresh_copy() {
  rm -rf "${WORK}/repo"
  mkdir -p "${WORK}/repo/scripts" "${WORK}/repo/flux"
  cp "${ROOT}/scripts/check-image-tags.sh" "${WORK}/repo/scripts/"
  cp -R "${ROOT}/flux/apps" "${WORK}/repo/flux/"
}

# run_case NAME EXPECTED(pass|fail) SED_EXPRESSION - apply the edit to the production backend
# overlay of a fresh copy, run the check, compare.
run_case() {
  local name="$1" expected="$2" edit="$3" file got
  fresh_copy
  file="${WORK}/repo/flux/apps/backend/production/kustomization.yaml"
  if [[ -n "${edit}" ]]; then
    sed -i.bak -e "${edit}" "${file}" && rm -f "${file}.bak"
  fi
  if "${WORK}/repo/scripts/check-image-tags.sh" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [[ "${got}" == "${expected}" ]]; then
    echo "ok   - ${name}"
  else
    echo "FAIL - ${name}: expected ${expected}, got ${got}"
    FAILED=1
  fi
}

run_case "the repository as it is" pass ""
run_case "a staging tag in production" fail 's/newTag: production-/newTag: staging-/'
run_case "a malformed production tag" fail 's/newTag: production-v[^ ]*/newTag: production-latest/'
run_case "the setter comment removed" fail 's/ # {"$imagepolicy": "production:backend:tag"}//'
run_case "the setter names another environment" fail 's/"production:backend:tag"/"staging:backend:tag"/'

exit "${FAILED}"

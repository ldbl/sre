#!/usr/bin/env bash
# Tests scripts/check-policy-exceptions.sh in a throw-away repository, one case at a time - no
# cluster. Each case writes one PolicyException (tests/kyverno/exceptions.yaml, changed by one yq
# edit) into a fresh copy, runs the check with a fixed NOW and compares the verdict.
# Run: tests/check-policy-exceptions.test.sh   (pre-commit runs it when the check or this test changes)
# Needs yq (v4), like the check. Exit 0 when every case passes, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
NOW="2026-10-06T12:00:00Z"   # fixed, so the cases do not expire; the check allows up to 2027-01-04

# run_case NAME EXPECTED(pass|fail) YQ_EDIT [DIR] - a fresh copy with the fixture exception, edited by
# YQ_EDIT (empty: as it is, "none": no exception at all), placed in DIR (default: the exceptions
# directory); run the check; compare.
run_case() {
  local name="$1" expected="$2" edit="$3" dir="${4:-flux/infrastructure/policy/exceptions}" got
  rm -rf "${WORK}/repo"
  mkdir -p "${WORK}/repo/scripts" "${WORK}/repo/flux/infrastructure/policy" "${WORK}/repo/${dir}"
  # The check, the policy packs (an exception must name one of their policies) and the case - not
  # the repository's own exceptions: their real expiry dates would fail against the fixed NOW. The
  # live ones are checked by the policy-exceptions hook.
  mkdir -p "${WORK}/repo/flux/infrastructure/policy/exceptions"
  cp "${ROOT}/scripts/check-policy-exceptions.sh" "${WORK}/repo/scripts/"
  cp -R "${ROOT}/flux/infrastructure/policy/packs" "${WORK}/repo/flux/infrastructure/policy/"
  if [[ "${edit}" != "none" ]]; then
    yq '.spec.expiresAt = "2026-12-31T00:00:00Z"' \
      "${ROOT}/tests/kyverno/exceptions.yaml" > "${WORK}/repo/${dir}/case.yaml"
    [[ -z "${edit}" ]] || yq -i "${edit}" "${WORK}/repo/${dir}/case.yaml"
  fi
  if NOW="${NOW}" "${WORK}/repo/scripts/check-policy-exceptions.sh" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [[ "${got}" == "${expected}" ]]; then
    echo "ok   - ${name}"
  else
    echo "FAIL - ${name}: expected ${expected}, got ${got}"
    FAILED=1
  fi
}

X='.spec.expiresAt'
C='.spec.matchConditions[0].expression'
R='.spec.policyRefs'
run_case "the repository as it is (no exceptions)" pass none
run_case "a narrow exception with owner, reason and expiry" pass ""
run_case "expires later today - still valid" pass "${X} = \"2026-10-06T18:00:00Z\""
run_case "expired this morning" fail "${X} = \"2026-10-06T00:00:00Z\""
run_case "expires more than 90 days ahead" fail "${X} = \"2027-01-05T00:00:00Z\""
run_case "no expiry" fail "del(${X})"
run_case "expiry not a time" fail "${X} = \"next sprint\""
run_case "a date without a time" fail "${X} = \"2026-12-31\""
run_case "not UTC (an offset)" fail "${X} = \"2026-12-31T00:00:00+02:00\""
run_case "an impossible date (30 February)" fail "${X} = \"2027-02-30T00:00:00Z\""
run_case "no owner" fail 'del(.metadata.annotations["safeops.io/owner"])'
run_case "empty reason" fail '.metadata.annotations["safeops.io/reason"] = ""'
run_case "another namespace - Kyverno would ignore it" fail '.metadata.namespace = "develop"'
run_case "outside the exceptions directory" fail "" flux/apps/backend/develop
run_case "an old kyverno.io exception (ClusterPolicy rules)" fail '.apiVersion = "kyverno.io/v2"'
run_case "an exact name instead of a prefix" pass \
  "${C} = \"object.metadata.namespace == 'develop' && object.metadata.name == 'vendor-agent'\""
run_case "no name - the whole namespace" fail "${C} = \"object.metadata.namespace == 'develop'\""
run_case "an empty prefix - the whole namespace" fail \
  "${C} = \"object.metadata.namespace == 'develop' && object.metadata.name.startsWith('')\""
run_case "an \"||\" - more than one workload" fail \
  "${C} = \"object.metadata.namespace == 'develop' && object.metadata.name == 'a' || true\""
run_case "a namespace prefix" fail \
  "${C} = \"object.metadata.namespace.startsWith('dev') && object.metadata.name == 'vendor-agent'\""
run_case "by label" fail \
  "${C} = \"object.metadata.namespace == 'develop' && object.metadata.labels['app'] == 'vendor-agent'\""
run_case "two conditions" fail '.spec.matchConditions += [{"name": "two", "expression": "true"}]'
run_case "no condition - everything" fail 'del(.spec.matchConditions)'
run_case "two policies in one exception" fail "${R} += [{\"name\": \"disallow-latest-tag-enforce\", \"kind\": \"ValidatingPolicy\"}]"
run_case "no policy" fail "${R} = []"
run_case "a policy that does not exist (typo)" fail "${R}[0].name = \"require-trusted-registry-enforce\""
run_case "the audit copy of a guardrail" pass "${R}[0].name = \"require-trusted-registries-audit\""
run_case "an ImageValidatingPolicy" pass "${R}[0] = {\"name\": \"verify-images-enforce\", \"kind\": \"ImageValidatingPolicy\"}"
run_case "the right name with the wrong kind" fail "${R}[0].kind = \"ImageValidatingPolicy\""
run_case "an image allow-list on top" fail '.spec.images = ["quay.io/*"]'

exit "${FAILED}"

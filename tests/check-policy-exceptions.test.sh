#!/usr/bin/env bash
# Tests scripts/check-policy-exceptions.sh in a throw-away repository, one case at a time - no
# cluster. Each case writes one PolicyException (tests/kyverno/exceptions.yaml, changed by one yq
# edit) into a fresh copy, runs the check with a fixed TODAY and compares the verdict.
# Run: tests/check-policy-exceptions.test.sh   (pre-commit runs it when the check or this test changes)
# Needs yq (v4), like the check. Exit 0 when every case passes, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
TODAY="2026-10-06"   # fixed, so the cases do not expire; the check allows up to 2027-01-04

# run_case NAME EXPECTED(pass|fail) YQ_EDIT [DIR] - a fresh copy with the fixture exception, edited by
# YQ_EDIT (empty: as it is, "none": no exception at all), placed in DIR (default: the exceptions
# directory); run the check; compare.
run_case() {
  local name="$1" expected="$2" edit="$3" dir="${4:-flux/infrastructure/policy/exceptions}" got
  rm -rf "${WORK}/repo"
  mkdir -p "${WORK}/repo/scripts" "${WORK}/repo/flux/infrastructure/policy" "${WORK}/repo/${dir}"
  # Only the check and the case - not the repository's own exceptions: their real expiry dates would
  # fail against the fixed TODAY. The live ones are checked by the policy-exceptions hook.
  mkdir -p "${WORK}/repo/flux/infrastructure/policy/exceptions"
  cp "${ROOT}/scripts/check-policy-exceptions.sh" "${WORK}/repo/scripts/"
  if [[ "${edit}" != "none" ]]; then
    yq '.metadata.annotations["safeops.io/expires"] = "2026-12-31"' \
      "${ROOT}/tests/kyverno/exceptions.yaml" > "${WORK}/repo/${dir}/case.yaml"
    [[ -z "${edit}" ]] || yq -i "${edit}" "${WORK}/repo/${dir}/case.yaml"
  fi
  if TODAY="${TODAY}" "${WORK}/repo/scripts/check-policy-exceptions.sh" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [[ "${got}" == "${expected}" ]]; then
    echo "ok   - ${name}"
  else
    echo "FAIL - ${name}: expected ${expected}, got ${got}"
    FAILED=1
  fi
}

M='.spec.match.any[0].resources'
run_case "the repository as it is (no exceptions)" pass none
run_case "a narrow exception with owner, reason and expiry" pass ""
run_case "expires today - still valid" pass '.metadata.annotations["safeops.io/expires"] = "2026-10-06"'
run_case "expired yesterday" fail '.metadata.annotations["safeops.io/expires"] = "2026-10-05"'
run_case "expires more than 90 days ahead" fail '.metadata.annotations["safeops.io/expires"] = "2027-01-05"'
run_case "expiry not a date" fail '.metadata.annotations["safeops.io/expires"] = "next sprint"'
run_case "an impossible date (30 February)" fail '.metadata.annotations["safeops.io/expires"] = "2026-02-30"'
run_case "an impossible month (13)" fail '.metadata.annotations["safeops.io/expires"] = "2026-13-01"'
run_case "no owner" fail 'del(.metadata.annotations["safeops.io/owner"])'
run_case "empty reason" fail '.metadata.annotations["safeops.io/reason"] = ""'
run_case "another namespace - Kyverno would ignore it" fail '.metadata.namespace = "develop"'
run_case "outside the exceptions directory" fail "" flux/apps/backend/develop
run_case "two namespaces in one entry" fail "${M}.namespaces = [\"develop\", \"staging\"]"
run_case "no namespace - the whole cluster" fail "del(${M}.namespaces)"
run_case "no resource names - the whole namespace" fail "del(${M}.names)"
run_case "a \"*\" name" fail "${M}.names = [\"*\"]"
run_case "a second entry (match.all) without names" fail \
  '.spec.match.all = [{"resources": {"kinds": ["Pod"], "namespaces": ["develop"]}}]'
run_case "\"?*\" as a name" fail "${M}.names = [\"?*\"]"
run_case "\"?*\" as the namespace" fail "${M}.namespaces = [\"?*\"]"
run_case "a namespace prefix (dev*)" fail "${M}.namespaces = [\"dev*\"]"
run_case "a named prefix (vendor-agent-*) is still narrow" pass "${M}.names = [\"vendor-agent-*\"]"
E='.spec.exceptions'
run_case "the rule and its autogen variants (a Deployment)" pass \
  "${E}[0].ruleNames = [\"trusted-registries-only\", \"autogen-trusted-registries-only\", \"autogen-cronjob-trusted-registries-only\"]"
run_case "two policies in one exception" fail \
  "${E} += [{\"policyName\": \"disallow-latest-tag\", \"ruleNames\": [\"no-latest\"]}]"
run_case "no exceptions entry" fail "${E} = []"
run_case "a \"*\" policy" fail "${E}[0].policyName = \"*\""
run_case "a \"*\" rule" fail "${E}[0].ruleNames = [\"*\"]"
run_case "a rule prefix with \"*\"" fail "${E}[0].ruleNames = [\"trusted-*\"]"
run_case "two different rules" fail "${E}[0].ruleNames = [\"trusted-registries-only\", \"no-latest\"]"
run_case "no rule names" fail "del(${E}[0].ruleNames)"

exit "${FAILED}"

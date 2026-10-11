#!/usr/bin/env bash
# check-policy-exceptions.sh - every Kyverno PolicyException in Git is narrow, owned and temporary.
#
# Why: a PolicyException switches a guardrail off for what it matches (Chapter 16). The cluster lets
# only Flux write one (flux/infrastructure/policy/exceptions/only-from-git.yaml), so this pull request
# check is where an exception is judged. For every PolicyException under flux/ it requires:
#   - apiVersion policies.kyverno.io/v1 - the guardrails are ValidatingPolicies; an older kyverno.io
#     exception names ClusterPolicy rules that no longer exist and would silently do nothing;
#   - the file is in flux/infrastructure/policy/exceptions/ and metadata.namespace is policy-exceptions
#     (Kyverno reads no other namespace - an exception elsewhere would silently do nothing);
#   - the annotations safeops.io/owner and safeops.io/reason;
#   - spec.expiresAt (RFC 3339, UTC: 2026-12-31T00:00:00Z) in the future and at most MAX_DAYS ahead.
#     Kyverno stops applying an exception at that moment; this check makes the date exist and short;
#   - exactly one policyRefs entry, naming a ValidatingPolicy or ImageValidatingPolicy that exists in
#     flux/infrastructure/policy/packs/ - a typo would except nothing and look as if it did;
#   - exactly one matchCondition, in one fixed form - one literal namespace and one workload name or
#     name prefix (a Deployment's pods are named <deployment>-<hash>-<id>):
#       object.metadata.namespace == 'develop' && object.metadata.name == 'vendor-agent'
#       object.metadata.namespace == 'develop' && object.metadata.name.startsWith('vendor-agent')
#     CEL can say anything; the fixed form is what keeps an exception reviewable - no exception for a
#     whole namespace, by label, or for the whole cluster;
#   - nothing else in spec (images, allowedValues, reportResult, ...).
# The expiry is checked on every run, not only when the file changes: CI runs every hook on every
# pull request, so an expired exception fails all of them until it is removed or renewed on purpose.
# .github/workflows/policy-exceptions-expiry.yml also runs this check on main every day: Kyverno has
# stopped applying an expired exception, and the file left in Git says otherwise.
#
# Runs in pre-commit (and with it in the CI `hooks` job). Needs yq (v4).
# Usage: scripts/check-policy-exceptions.sh   (no arguments; reads flux/)
#        NOW=2026-10-06T12:00:00Z scripts/check-policy-exceptions.sh   (tests: a fixed "now", UTC)
# Read-only: changes no file and no cluster. Exit 0 when every exception passes, 1 otherwise.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

command -v yq >/dev/null || { echo "check-policy-exceptions: yq is required (make check-tools)" >&2; exit 1; }

EXCEPTIONS_DIR="flux/infrastructure/policy/exceptions"
PACKS_DIR="flux/infrastructure/policy/packs"
MAX_DAYS=90
NOW="${NOW:-$(date -u +%FT%TZ)}"
TODAY="${NOW%%T*}"

# latest_expiry - TODAY + MAX_DAYS as YYYY-MM-DD; BSD date (macOS) and GNU date (Linux) differ here.
latest_expiry() {
  date -u -j -v+"${MAX_DAYS}"d -f %F "${TODAY}" +%F 2>/dev/null \
    || date -u -d "${TODAY} + ${MAX_DAYS} days" +%F
}
LATEST="$(latest_expiry)"

# is_calendar_date DATE - true when DATE (YYYY-MM-DD) is a real day. GNU date refuses 2026-02-30;
# BSD date rolls it over to 2026-03-02 - so the date must come back unchanged.
is_calendar_date() {
  local normalized
  normalized="$(date -u -d "$1" +%F 2>/dev/null || date -u -j -f %F "$1" +%F 2>/dev/null || true)"
  [[ "${normalized}" == "$1" ]]
}

# The one accepted matchCondition: a literal namespace (a Kubernetes name) and a literal name or name
# prefix - never empty, no regex, no label, no "||".
K8S_NAME="[a-z0-9]([-a-z0-9]*[a-z0-9])?"
MATCH_FORM="^object\.metadata\.namespace == '${K8S_NAME}' && object\.metadata\.name( == '[a-z0-9][-a-z0-9.]*'|\.startsWith\('[a-z0-9][-a-z0-9.]*'\))$"

# Every "<kind>/<name>" a PolicyException may reference: the CEL policies of the packs.
known_policies="$(find "${PACKS_DIR}" -name '*.yaml' -exec yq -N \
  'select(.kind | test("^(Image)?ValidatingPolicy$")) | [.kind, .metadata.name] | join("/")' {} + | sort -u)"

failures=()
checked=0

# Every YAML file under flux/ that holds a PolicyException - found by kind with yq, not by path, so
# one placed anywhere else is caught too.
while IFS= read -r file; do
  count="$(yq ea '[select(tag == "!!map" and .kind == "PolicyException")] | length' "${file}")"
  [[ "${count}" -gt 0 ]] || continue
  for ((i = 0; i < count; i++)); do
    doc="$(yq ea "[select(tag == \"!!map\" and .kind == \"PolicyException\")] | .[${i}]" "${file}")"
    name="$(yq '.metadata.name' <<<"${doc}")"
    where="${file}: PolicyException '${name}'"
    checked=$((checked + 1))

    [[ "$(yq '.apiVersion' <<<"${doc}")" == "policies.kyverno.io/v1" ]] \
      || failures+=("${where}: apiVersion must be policies.kyverno.io/v1 (an exception to the CEL policies)")
    [[ "$(dirname "${file}")" == "${EXCEPTIONS_DIR}" ]] \
      || failures+=("${where}: must live in ${EXCEPTIONS_DIR}/")
    [[ "$(yq '.metadata.namespace' <<<"${doc}")" == "policy-exceptions" ]] \
      || failures+=("${where}: metadata.namespace must be policy-exceptions (Kyverno reads no other)")

    for key in owner reason; do
      value="$(yq ".metadata.annotations[\"safeops.io/${key}\"] // \"\"" <<<"${doc}")"
      [[ -n "${value}" ]] || failures+=("${where}: annotation safeops.io/${key} is missing")
    done

    # RFC 3339 in UTC compares as a string: "2026-10-06T00:00:00Z" < "2026-10-06T12:00:00Z".
    expires="$(yq '.spec.expiresAt // ""' <<<"${doc}")"
    if [[ ! "${expires}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]Z$ ]] \
      || ! is_calendar_date "${BASH_REMATCH[1]}"; then
      failures+=("${where}: spec.expiresAt must be a real UTC time, YYYY-MM-DDTHH:MM:SSZ (got '${expires}')")
    elif [[ ! "${expires}" > "${NOW}" ]]; then
      failures+=("${where}: expired at ${expires} - Kyverno no longer applies it; remove it, or renew it in a pull request that says why")
    elif [[ "${BASH_REMATCH[1]}" > "${LATEST}" ]]; then
      failures+=("${where}: expires ${expires}, more than ${MAX_DAYS} days ahead (latest ${LATEST})")
    fi

    extra="$(yq '.spec | keys | map(select(. != "expiresAt" and . != "policyRefs" and . != "matchConditions")) | join(", ")' <<<"${doc}")"
    [[ -z "${extra}" ]] || failures+=("${where}: spec may hold only expiresAt, policyRefs and matchConditions (also has: ${extra})")

    # What it switches off: one policy that exists.
    if [[ "$(yq '.spec.policyRefs | length' <<<"${doc}")" != "1" ]]; then
      failures+=("${where}: spec.policyRefs must have exactly one entry (one policy)")
    else
      ref="$(yq '(.spec.policyRefs[0].kind // "") + "/" + (.spec.policyRefs[0].name // "")' <<<"${doc}")"
      grep -qxF -- "${ref}" <<<"${known_policies}" \
        || failures+=("${where}: spec.policyRefs names ${ref}, which is not a ValidatingPolicy or ImageValidatingPolicy in ${PACKS_DIR}/")
    fi

    # What it matches: one namespace, one workload - in the fixed form.
    if [[ "$(yq '.spec.matchConditions | length' <<<"${doc}")" != "1" ]]; then
      failures+=("${where}: spec.matchConditions must have exactly one entry")
    else
      expression="$(yq '.spec.matchConditions[0].expression // ""' <<<"${doc}")"
      [[ "${expression}" =~ ${MATCH_FORM} ]] \
        || failures+=("${where}: matchConditions[0].expression must be object.metadata.namespace == '<namespace>' && object.metadata.name == '<name>' (or .startsWith('<prefix>')), got: ${expression}")
    fi
  done
done < <(find flux -name '*.yaml' -o -name '*.yml' | sort)

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "check-policy-exceptions: ${#failures[@]} problem(s):" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-policy-exceptions: ${checked} exception(s) OK (now ${NOW}, latest allowed expiry ${LATEST})"

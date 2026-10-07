#!/usr/bin/env bash
# check-policy-exceptions.sh - every Kyverno PolicyException in Git is narrow, owned and temporary.
#
# Why: a PolicyException switches a guardrail off for what it matches (Chapter 16). The cluster lets
# only Flux write one (flux/infrastructure/policy/exceptions/only-from-git.yaml), so this pull request
# check is where an exception is judged. For every PolicyException under flux/ it requires:
#   - the file is in flux/infrastructure/policy/exceptions/ and metadata.namespace is policy-exceptions
#     (Kyverno reads no other namespace - an exception elsewhere would silently do nothing);
#   - the annotations safeops.io/owner, safeops.io/reason and safeops.io/expires (YYYY-MM-DD);
#   - an expiry date not in the past and at most MAX_DAYS ahead - temporary means a date;
#   - exactly one policy and one rule (plus its autogen-<rule> variants), no "*";
#   - in every match entry exactly one literal namespace and at least one resource name that is not
#     only wildcards (*, ?) - no exception for a whole namespace or the whole cluster.
# The expiry is checked on every run, not only when the file changes: CI runs every hook on every
# pull request, so an expired exception fails all of them until it is removed or renewed on purpose.
#
# Runs in pre-commit (and with it in the CI `hooks` job). Needs yq (v4).
# Usage: scripts/check-policy-exceptions.sh   (no arguments; reads flux/)
#        TODAY=2026-10-06 scripts/check-policy-exceptions.sh   (tests: a fixed "today", UTC)
# Read-only: changes no file and no cluster. Exit 0 when every exception passes, 1 otherwise.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

command -v yq >/dev/null || { echo "check-policy-exceptions: yq is required (make check-tools)" >&2; exit 1; }

EXCEPTIONS_DIR="flux/infrastructure/policy/exceptions"
MAX_DAYS=90
TODAY="${TODAY:-$(date -u +%F)}"

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

    [[ "$(dirname "${file}")" == "${EXCEPTIONS_DIR}" ]] \
      || failures+=("${where}: must live in ${EXCEPTIONS_DIR}/")
    [[ "$(yq '.metadata.namespace' <<<"${doc}")" == "policy-exceptions" ]] \
      || failures+=("${where}: metadata.namespace must be policy-exceptions (Kyverno reads no other)")

    for key in owner reason; do
      value="$(yq ".metadata.annotations[\"safeops.io/${key}\"] // \"\"" <<<"${doc}")"
      [[ -n "${value}" ]] || failures+=("${where}: annotation safeops.io/${key} is missing")
    done

    expires="$(yq '.metadata.annotations["safeops.io/expires"] // ""' <<<"${doc}")"
    if [[ ! "${expires}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! is_calendar_date "${expires}"; then
      failures+=("${where}: annotation safeops.io/expires must be a real date, YYYY-MM-DD (got '${expires}')")
    elif [[ "${expires}" < "${TODAY}" ]]; then
      failures+=("${where}: expired on ${expires} - remove it, or renew it in a pull request that says why")
    elif [[ "${expires}" > "${LATEST}" ]]; then
      failures+=("${where}: expires ${expires}, more than ${MAX_DAYS} days ahead (latest ${LATEST})")
    fi

    # What it switches off: one policy, one rule. ruleNames may add the rule's generated variants for
    # pod controllers (autogen-<rule>, autogen-cronjob-<rule>) - an exception for a Deployment needs
    # them - but no other rule and no "*".
    if [[ "$(yq '.spec.exceptions | length' <<<"${doc}")" != "1" ]]; then
      failures+=("${where}: spec.exceptions must have exactly one entry (one policy)")
    else
      policy="$(yq '.spec.exceptions[0].policyName // ""' <<<"${doc}")"
      [[ -n "${policy}" && "${policy}" != *"*"* ]] \
        || failures+=("${where}: spec.exceptions[0].policyName must name one policy, without \"*\"")
      rules="$(yq '.spec.exceptions[0].ruleNames[]' <<<"${doc}" 2>/dev/null || true)"
      base=""
      [[ -n "${rules}" ]] || failures+=("${where}: spec.exceptions[0].ruleNames must name the rule")
      while IFS= read -r rule; do
        [[ -n "${rule}" ]] || continue
        if [[ "${rule}" == *"*"* ]]; then
          failures+=("${where}: rule name '${rule}' uses \"*\"")
          continue
        fi
        stripped="${rule#autogen-cronjob-}"
        stripped="${stripped#autogen-}"
        if [[ -z "${base}" ]]; then
          base="${stripped}"
        elif [[ "${stripped}" != "${base}" ]]; then
          failures+=("${where}: ruleNames name more than one rule ('${base}' and '${stripped}') - one exception per rule")
        fi
      done <<<"${rules}"
    fi

    # Every match entry (any and all): one namespace, named resources, no "*".
    entries="$(yq '[.spec.match.any[], .spec.match.all[]] | length' <<<"${doc}" 2>/dev/null || echo 0)"
    [[ "${entries}" -gt 0 ]] || failures+=("${where}: spec.match names nothing")
    for ((m = 0; m < entries; m++)); do
      entry="[.spec.match.any[], .spec.match.all[]] | .[${m}].resources"
      [[ "$(yq "${entry}.namespaces | length" <<<"${doc}")" == "1" ]] \
        || failures+=("${where}: match entry ${m} must name exactly one namespace")
      [[ "$(yq "${entry}.names | length" <<<"${doc}")" -ge 1 ]] \
        || failures+=("${where}: match entry ${m} must name the resources (resources.names)")
      # Kyverno matches namespaces and names as wildcards (* and ?). A namespace must be literal; a
      # name may be a prefix such as vendor-agent-*, but not only wildcards (*, ?*, ...).
      if [[ "$(yq "[${entry}.namespaces[]] | any_c(test(\"[*?]\"))" <<<"${doc}")" == "true" ]]; then
        failures+=("${where}: match entry ${m} uses a wildcard (* or ?) in a namespace")
      fi
      if [[ "$(yq "[${entry}.names[]] | any_c(test(\"^[*?]+\$\"))" <<<"${doc}")" == "true" ]]; then
        failures+=("${where}: match entry ${m} has a name made only of wildcards (* or ?)")
      fi
    done
  done
done < <(find flux -name '*.yaml' -o -name '*.yml' | sort)

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "check-policy-exceptions: ${#failures[@]} problem(s):" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-policy-exceptions: ${checked} exception(s) OK (today ${TODAY}, latest allowed expiry ${LATEST})"

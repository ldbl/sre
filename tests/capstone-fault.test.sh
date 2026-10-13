#!/usr/bin/env bash
# Tests scripts/capstone-fault.sh in a throw-away repository - no cluster, no GitHub. For each fault:
# a fresh copy of flux/ and scripts/, then `capstone-fault.sh --local` with that fault chosen, and
# three questions: did it make exactly one commit, by the colleague, on a new branch; does the change
# say what the fault is meant to say (one grep each); and does it still pass the platform's own
# checks (check-app-security.sh, check-app-resources.sh) - a fault the pull request checks catch
# would never reach the cluster, and the capstone would have nothing to find.
# Run: tests/capstone-fault.test.sh   (pre-commit runs it when the script, this test or a file a
# fault edits changes - so an edit that breaks a fault fails here, not in a learner's capstone)
# Needs git, yq (v4) and kubectl (kustomize), like the checks. Exit 0 when every case passes, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# fresh_repo - ${WORK}/repo: a git repository with this repository's flux/ and scripts/, one commit.
# Its own identity, no signing and no hooks - the test must not depend on the machine's git setup.
fresh_repo() {
  local repo="${WORK}/repo"
  rm -rf "${repo}"
  mkdir -p "${repo}"
  cp -R "${ROOT}/flux" "${ROOT}/scripts" "${repo}/"
  git -C "${repo}" init -q -b main
  git -C "${repo}" config user.name test
  git -C "${repo}" config user.email test@example.invalid
  git -C "${repo}" config commit.gpgsign false
  git -C "${repo}" config core.hooksPath /dev/null
  git -C "${repo}" add -A
  git -C "${repo}" commit -q -m base
}

# check NAME COMMAND... - one assertion: the command succeeds. A call without a command fails.
check() {
  local name="$1"
  if [[ $# -lt 2 ]]; then
    echo "FAIL - ${name}: no command to check"
    FAILED=1
    return
  fi
  shift
  if "$@" >/dev/null 2>&1; then
    echo "ok   - ${name}"
  else
    echo "FAIL - ${name}"
    FAILED=1
  fi
}

# run_fault FAULT EXPECTED_DIFF_REGEX - make FAULT in a fresh copy and check it.
run_fault() {
  local fault="$1" expected="$2" repo="${WORK}/repo"
  fresh_repo
  if ! CAPSTONE_FAULT="${fault}" "${repo}/scripts/capstone-fault.sh" --local >"${WORK}/out" 2>&1; then
    echo "FAIL - ${fault}: capstone-fault.sh --local failed:"
    sed 's/^/       /' "${WORK}/out"
    FAILED=1
    return
  fi
  check "${fault}: one commit on a new branch" \
    test "$(git -C "${repo}" rev-list --count main..HEAD)" -eq 1
  check "${fault}: authored by the colleague" \
    grep -q 'Mira Koleva' <<<"$(git -C "${repo}" log -1 --format=%an)"
  check "${fault}: the change is the fault" \
    grep -Eq "${expected}" <<<"$(git -C "${repo}" show --format= -U0 HEAD)"
  check "${fault}: the working copy is clean" \
    test -z "$(git -C "${repo}" status --porcelain)"
  check "${fault}: passes check-app-security.sh" "${repo}/scripts/check-app-security.sh"
  check "${fault}: passes check-app-resources.sh" "${repo}/scripts/check-app-resources.sh"
}

run_fault f1 '^\+ +value: "1"$'
run_fault f2 '^\+ +values: \[app-postgres-rw\]$'
run_fault f3 '^\+ +cpu: 25m$'

# An unknown fault is refused, and nothing is committed.
fresh_repo
check "an unknown fault is refused" \
  bash -c "! CAPSTONE_FAULT=f9 '${WORK}/repo/scripts/capstone-fault.sh' --local"
check "  - and nothing changed" test "$(git -C "${WORK}/repo" rev-list --count HEAD)" -eq 1

# A branch that exists already is refused, and the checkout is left as it was.
fresh_repo
CAPSTONE_FAULT=f1 "${WORK}/repo/scripts/capstone-fault.sh" --local >/dev/null 2>&1
git -C "${WORK}/repo" switch -q main
check "an existing branch is refused" \
  bash -c "! CAPSTONE_FAULT=f1 '${WORK}/repo/scripts/capstone-fault.sh' --local"
check "  - and the checkout is clean, still on main" \
  test "$(git -C "${WORK}/repo" status --porcelain)$(git -C "${WORK}/repo" branch --show-current)" = main

exit "${FAILED}"

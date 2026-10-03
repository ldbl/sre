#!/usr/bin/env bash
# Tests scripts/prevent-amend-after-push.sh in a throw-away repository with a local bare "remote" -
# nothing on GitHub, no pre-commit needed.
# Run: tests/prevent-amend-after-push.test.sh   (pre-commit runs it when the hook or this test changes)
# The hook gets the message source and the commit two ways: from git as $2 $3, and from pre-commit as
# PRE_COMMIT_COMMIT_MSG_SOURCE / PRE_COMMIT_COMMIT_OBJECT_NAME (make install-hooks runs it through
# pre-commit). Each case runs one of them and compares the verdict: block (exit 1) or allow (exit 0).
# Exit 0 when every case passes, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${ROOT}/scripts/prevent-amend-after-push.sh"
FAILED=0

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
git init -q --bare "${WORK}/remote.git"
git init -q "${WORK}/repo"
cd "${WORK}/repo"
git config user.email test@example.invalid
git config user.name test
git config commit.gpgsign false
git remote add origin "${WORK}/remote.git"

git commit -q --allow-empty -m pushed
git push -q origin HEAD:refs/heads/lab
git fetch -q origin
PUSHED="$(git rev-parse HEAD)"
git commit -q --allow-empty -m local
LOCAL="$(git rev-parse HEAD)"

# check <block|allow> <name> <command...> - run the hook the given way and compare its verdict.
check() {
  local want="$1" name="$2" rc=0
  shift 2
  "$@" >/dev/null 2>&1 || rc=$?
  local got="allow"
  [[ "${rc}" -ne 0 ]] && got="block"
  if [[ "${got}" == "${want}" ]]; then
    echo "ok   ${want}: ${name}"
  else
    echo "FAIL ${name}: want ${want}, got ${got}" >&2
    FAILED=1
  fi
}

# The way pre-commit calls it: no positional arguments, the values in the environment.
check block "pre-commit: amend of a pushed commit" \
  env PRE_COMMIT_COMMIT_MSG_SOURCE=commit PRE_COMMIT_COMMIT_OBJECT_NAME="${PUSHED}" "${HOOK}"
check allow "pre-commit: amend of a local commit" \
  env PRE_COMMIT_COMMIT_MSG_SOURCE=commit PRE_COMMIT_COMMIT_OBJECT_NAME="${LOCAL}" "${HOOK}"
check allow "pre-commit: a normal commit (source message)" \
  env PRE_COMMIT_COMMIT_MSG_SOURCE=message "${HOOK}"

# The way git calls a plain hook: <message file> <source> <sha>.
check block "git: amend of a pushed commit" "${HOOK}" .git/COMMIT_EDITMSG commit "${PUSHED}"
check allow "git: amend of a local commit" "${HOOK}" .git/COMMIT_EDITMSG commit "${LOCAL}"
check allow "git: a normal commit" "${HOOK}" .git/COMMIT_EDITMSG message

exit "${FAILED}"

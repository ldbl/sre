#!/usr/bin/env bash
# Tests scripts/check-sops-encrypted.sh on throw-away files - no sops, no cluster, no real secrets.
# Run: tests/check-sops-encrypted.test.sh   (pre-commit runs it when the check or this test changes)
# Each case writes one file under flux/secrets/ in a temporary git repository, runs the check on it
# and compares the verdict (pass/fail). Every case also proves that the output never contains the
# value - the check runs in CI, and the CI logs of this repository are public.
# Exit 0 when every case passes, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="${ROOT}/scripts/check-sops-encrypted.sh"
FAILED=0

# The check works from the root of the git repository it runs in, so give it its own.
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
git -C "${WORK}" init -q
mkdir -p "${WORK}/flux/secrets/local"

# A value that must never appear in the output.
VALUE="not-a-real-secret-4711"
# What sops writes after the values: the metadata block that marks a file as encrypted.
SOPS_META='sops:
    age:
        - recipient: age1example
    mac: ENC[AES256_GCM,data:abc,iv:def,tag:ghi,type:str]
    version: 3.13.3'

# check <pass|fail> <name> <file content> - write the file, run the check, compare the verdict
# and make sure VALUE is not in the output.
check() {
  local want="$1" name="$2" content="$3" rc=0 out
  printf '%s\n' "${content}" > "${WORK}/flux/secrets/local/case.yaml"
  out="$(cd "${WORK}" && "${CHECK}" flux/secrets/local/case.yaml 2>&1)" || rc=$?
  local got="pass"
  [[ "${rc}" -ne 0 ]] && got="fail"
  if [[ "${got}" != "${want}" ]]; then
    echo "FAIL ${name}: want ${want}, got ${got}" >&2
    FAILED=1
  elif [[ "${out}" == *"${VALUE}"* ]]; then
    echo "FAIL ${name}: the value appears in the output" >&2
    FAILED=1
  else
    echo "ok   ${want}: ${name}"
  fi
}

check pass "encrypted Secret" "apiVersion: v1
kind: Secret
metadata:
  name: case
stringData:
  token: ENC[AES256_GCM,data:abc,iv:def,tag:ghi,type:str]
${SOPS_META}"

check fail "plaintext Secret (no sops metadata)" "apiVersion: v1
kind: Secret
metadata:
  name: case
stringData:
  token: ${VALUE}"

check fail "plaintext value added to an encrypted file" "apiVersion: v1
kind: Secret
stringData:
  token: ENC[AES256_GCM,data:abc,iv:def,tag:ghi,type:str]
  extra: ${VALUE}
${SOPS_META}"

check fail "inline plaintext value" "apiVersion: v1
kind: Secret
stringData: {token: ${VALUE}}
${SOPS_META}"

check fail "quoted key with a plaintext value" "apiVersion: v1
kind: Secret
\"stringData\":
  token: ${VALUE}
${SOPS_META}"

check fail "single-quoted data key with a plaintext value" "apiVersion: v1
kind: Secret
'data':
  token: ${VALUE}
${SOPS_META}"

exit "${FAILED}"

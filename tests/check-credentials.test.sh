#!/usr/bin/env bash
# Tests scripts/check-credentials.sh in a throw-away repository, one case at a time - no secrets, no
# network. Each case writes a one-entry registry (a token rotated 2026-09-01, changed by one yq edit),
# a runbook with its heading and one SOPS-looking file, runs the check with a fixed TODAY and compares
# the verdict.
# Run: tests/check-credentials.test.sh   (pre-commit runs it when the check or this test changes)
# Needs yq (v4), like the check. Exit 0 when every case passes, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
TODAY="2026-10-11"   # fixed: the token below is due 2026-11-30, the check fails from 2026-11-16

# run_case NAME EXPECTED(pass|fail) YQ_EDIT [SHELL_SETUP] - a fresh copy with the fixture registry,
# edited by YQ_EDIT (empty: as it is); SHELL_SETUP runs inside the copy before the check; compare.
run_case() {
  local name="$1" expected="$2" edit="$3" setup="${4:-}" got
  rm -rf "${WORK}/repo"
  mkdir -p "${WORK}/repo/scripts" "${WORK}/repo/docs" "${WORK}/repo/flux/secrets/develop"
  cp "${ROOT}/scripts/check-credentials.sh" "${WORK}/repo/scripts/"
  printf '# Runbooks\n\n## Example API Token\n\nSteps.\n' > "${WORK}/repo/docs/credential-rotation.md"
  printf 'kind: Secret\nstringData:\n  api-token: ENC[AES256_GCM,data:x]\n' > "${WORK}/repo/flux/secrets/develop/example.yaml"
  printf 'resources: []\n' > "${WORK}/repo/flux/secrets/develop/kustomization.yaml"
  cat > "${WORK}/repo/docs/credential-registry.yaml" <<'EOF'
credentials:
  - name: example-token
    what: reads the example API
    class: token
    lives_in:
      - flux/secrets/develop/example.yaml (api-token)
      - GitHub organization secret EXAMPLE_TOKEN
    used_by: the example service
    rotated: 2026-09-01
    runbook: docs/credential-rotation.md#example-api-token
EOF
  [[ -z "${edit}" ]] || yq -i "${edit}" "${WORK}/repo/docs/credential-registry.yaml"
  [[ -z "${setup}" ]] || (cd "${WORK}/repo" && eval "${setup}")
  if (cd "${WORK}/repo" && TODAY="${TODAY}" CHECK_CREDENTIALS_DATES="${DATES_MODE:-enforce}" scripts/check-credentials.sh >/dev/null 2>&1); then got=pass; else got=fail; fi
  if [[ "${got}" == "${expected}" ]]; then
    echo "ok   - ${name}"
  else
    echo "FAIL - ${name}: expected ${expected}, got ${got}"
    FAILED=1
  fi
}

E='.credentials[0]'
run_case "a described token, rotated 40 days ago" pass ""
# Due dates: token 90 days, key 180; the check fails 14 days ahead.
run_case "a token due in 15 days (rotated 2026-07-28)" pass "${E}.rotated = \"2026-07-28\""
run_case "a token due in 14 days - fails, time to rotate" fail "${E}.rotated = \"2026-07-27\""
run_case "a token overdue" fail "${E}.rotated = \"2026-06-01\""
run_case "a key rotated 120 days ago (due after 180)" pass "${E}.class = \"key\" | ${E}.rotated = \"2026-06-13\""
run_case "a key overdue" fail "${E}.class = \"key\" | ${E}.rotated = \"2026-03-01\""
run_case "rotated in the future" fail "${E}.rotated = \"2026-10-12\""
run_case "rotated not a date" fail "${E}.rotated = \"last month\""
run_case "rotated an impossible date (30 February)" fail "${E}.rotated = \"2026-02-30\""
run_case "a token without rotated" fail "del(${E}.rotated)"
# class cluster: no dates of its own.
run_case "a cluster credential without rotated" pass "${E}.class = \"cluster\" | del(${E}.rotated)"
run_case "a cluster credential with rotated" fail "${E}.class = \"cluster\""
run_case "an unknown class" fail "${E}.class = \"password\""
# The provider's own end date.
run_case "expires in 30 days" pass "${E}.expires = \"2026-11-10\""
run_case "expires in 10 days" fail "${E}.expires = \"2026-10-21\""
run_case "expires on the rotation due date" pass "${E}.expires = \"2026-11-30\""
run_case "expires after the rotation is due" fail "${E}.expires = \"2026-12-01\""
run_case "a key may expire up to 180 days after rotation" pass "${E}.class = \"key\" | ${E}.expires = \"2027-02-28\""
# A leaked value is due at once - unless replaced after the leak.
run_case "exposed, not replaced since" fail "${E}.exposed = \"2026-09-20\""
run_case "exposed, replaced after" pass "${E}.exposed = \"2026-08-20\""
run_case "exposed and replaced the same day" pass "${E}.exposed = \"2026-09-01\""
run_case "exposed in the future" fail "${E}.exposed = \"2026-10-20\""
# Accepted debt: only for what fails, for at most 30 days, with a reason.
run_case "exposed, accepted for 20 days with a reason" pass \
  "${E}.exposed = \"2026-09-20\" | ${E}.accepted = {\"since\": \"2026-10-11\", \"until\": \"2026-10-31\", \"reason\": \"ingest only\"}"
run_case "accepted for 40 days" fail \
  "${E}.exposed = \"2026-09-20\" | ${E}.accepted = {\"since\": \"2026-10-11\", \"until\": \"2026-11-20\", \"reason\": \"ingest only\"}"
run_case "accepted until yesterday" fail \
  "${E}.exposed = \"2026-09-20\" | ${E}.accepted = {\"since\": \"2026-10-01\", \"until\": \"2026-10-10\", \"reason\": \"ingest only\"}"
run_case "accepted without a reason" fail \
  "${E}.exposed = \"2026-09-20\" | ${E}.accepted = {\"since\": \"2026-10-11\", \"until\": \"2026-10-31\"}"
run_case "accepted without since" fail \
  "${E}.exposed = \"2026-09-20\" | ${E}.accepted = {\"until\": \"2026-10-31\", \"reason\": \"ingest only\"}"
run_case "accepted since a day in the future" fail \
  "${E}.exposed = \"2026-09-20\" | ${E}.accepted = {\"since\": \"2026-10-12\", \"until\": \"2026-10-31\", \"reason\": \"ingest only\"}"
# The old limit was today + 30: moving `until` on every few weeks kept a debt forever. Counted from
# since, 60 days fail even though the end is less than 30 days from today.
run_case "accepted 60 days, the end moved on" fail \
  "${E}.exposed = \"2026-09-20\" | ${E}.accepted = {\"since\": \"2026-09-01\", \"until\": \"2026-10-31\", \"reason\": \"ingest only\"}"
run_case "accepted, but nothing is due" fail "${E}.accepted = {\"since\": \"2026-10-11\", \"until\": \"2026-10-31\", \"reason\": \"just in case\"}"
run_case "overdue, accepted" pass \
  "${E}.rotated = \"2026-06-01\" | ${E}.accepted = {\"since\": \"2026-10-11\", \"until\": \"2026-10-31\", \"reason\": \"provider outage\"}"

# Report mode - a fork: SafeOps' dates are printed, not failed; everything else still fails.
DATES_MODE=report run_case "report mode: an overdue token passes" pass "${E}.rotated = \"2026-06-01\""
DATES_MODE=report run_case "report mode: exposed, not replaced, passes" pass "${E}.exposed = \"2026-09-20\""
DATES_MODE=report run_case "report mode: a missing description still fails" fail "${E}.rotated = \"2026-06-01\" | del(${E}.what)"
DATES_MODE=report run_case "report mode: an unlisted SOPS file still fails" fail "" "printf 'kind: Secret\n' > flux/secrets/develop/new.yaml"
DATES_MODE=sometimes run_case "an unknown dates mode fails" fail ""
# Described: what, where, who, how.
run_case "no what" fail "del(${E}.what)"
run_case "no used_by" fail "del(${E}.used_by)"
run_case "empty lives_in" fail "${E}.lives_in = []"
run_case "a name used twice" fail ".credentials += [.credentials[0]]"
run_case "runbook without an anchor" fail "${E}.runbook = \"docs/credential-rotation.md\""
run_case "runbook anchor with no heading" fail "${E}.runbook = \"docs/credential-rotation.md#another-token\""
run_case "runbook file missing" fail "${E}.runbook = \"docs/missing.md#example-api-token\""
# Coverage: every key of every SOPS file is in the registry, every named file and key exists.
run_case "a second key in a listed file, not named" fail "" \
  "printf '  webhook-url: ENC[AES256_GCM,data:y]\n' >> flux/secrets/develop/example.yaml"
run_case "a second key, named in lives_in" pass "${E}.lives_in[0] = \"flux/secrets/develop/example.yaml (api-token, webhook-url)\"" \
  "printf '  webhook-url: ENC[AES256_GCM,data:y]\n' >> flux/secrets/develop/example.yaml"
run_case "a bare file name covers every key" pass "${E}.lives_in[0] = \"flux/secrets/develop/example.yaml\"" \
  "printf '  webhook-url: ENC[AES256_GCM,data:y]\n' >> flux/secrets/develop/example.yaml"
run_case "lives_in names a key the file does not have" fail "${E}.lives_in[0] = \"flux/secrets/develop/example.yaml (api-token, gone)\""
run_case "a SOPS file nobody lists" fail "" "printf 'kind: Secret\n' > flux/secrets/develop/new.yaml"
run_case "a SOPS file ending in .yml nobody lists" fail "" "printf 'kind: Secret\nstringData:\n  token: ENC[AES256_GCM,data:z]\n' > flux/secrets/develop/new.yml"
run_case "a kustomization.yml is not a credential" pass "" "printf 'resources: []\n' > flux/secrets/develop/kustomization.yml"
run_case "an .example template is not a credential" pass "" "printf 'kind: Secret\n' > flux/secrets/develop/new.yaml.example"
run_case "lives_in names a file that does not exist" fail "${E}.lives_in += [\"flux/secrets/staging/gone.yaml\"]"
run_case "no credentials at all" fail ".credentials = []"

exit "${FAILED}"

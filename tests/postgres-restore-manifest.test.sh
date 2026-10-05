#!/usr/bin/env bash
# Tests scripts/postgres-restore-manifest.sh against a stub kubectl - no cluster.
# Run: tests/postgres-restore-manifest.test.sh   (pre-commit runs it when the script or this test changes)
# The stub answers the two reads the script makes (the source Cluster, the backup Secret) and logs
# every call, so a case can check the printed manifest, the exit code and the --context used.
# Needs yq (v4) to parse the manifest. Exit 0 when every case passes, 1 otherwise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${ROOT}/scripts/postgres-restore-manifest.sh"
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# The stub kubectl: logs its arguments; returns a source Cluster as JSON, or one key of the backup
# Secret base64-encoded. STUB_NO_BUCKET=1 makes the Secret lack BUCKET.
mkdir -p "${WORK}/bin"
cat > "${WORK}/bin/kubectl" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "${STUB_LOG}"
case "$*" in
  *"get cluster.postgresql.cnpg.io app-postgres -o json"*)
    echo '{"spec":{"imageName":"ghcr.io/cloudnative-pg/postgresql:17","storage":{"size":"10Gi"},"resources":{"limits":{"memory":"512Mi"}}}}' ;;
  *"jsonpath={.data.BUCKET}"*) [ "${STUB_NO_BUCKET:-0}" = 1 ] || printf '%s' bkt | base64 ;;
  *"jsonpath={.data.ENDPOINT}"*) printf '%s' http://minio:9000 | base64 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "${WORK}/bin/kubectl"
export PATH="${WORK}/bin:${PATH}" STUB_LOG="${WORK}/calls.log"

# check NAME CONDITION - report one assertion; CONDITION is evaluated by bash.
check() {
  if eval "$2"; then echo "ok   - $1"; else echo "FAIL - $1"; FAILED=1; fi
}

# run ARGS... - run the script; stdout to WORK/out.yaml, stderr to WORK/err.txt, exit code to RC.
# shellcheck disable=SC2034  # RC is read by the conditions check() evaluates
run() {
  : > "${STUB_LOG}"
  set +e; "${SCRIPT}" "$@" > "${WORK}/out.yaml" 2> "${WORK}/err.txt"; RC=$?; set -e
}

run -n develop
check "full restore: exit 0" '[ "${RC}" = 0 ]'
check "full restore: valid YAML, kind Cluster" '[ "$(yq ".kind" "${WORK}/out.yaml")" = Cluster ]'
check "serverName is the source cluster" '[ "$(yq ".spec.externalClusters[0].barmanObjectStore.serverName" "${WORK}/out.yaml")" = app-postgres ]'
check "destinationPath from the Secret's bucket and the namespace" '[ "$(yq ".spec.externalClusters[0].barmanObjectStore.destinationPath" "${WORK}/out.yaml")" = s3://bkt/cnpg-backups/develop/app-postgres ]'
check "image copied from the source" '[ "$(yq ".spec.imageName" "${WORK}/out.yaml")" = ghcr.io/cloudnative-pg/postgresql:17 ]'
check "resources copied from the source" '[ "$(yq ".spec.resources.limits.memory" "${WORK}/out.yaml")" = 512Mi ]'
check "name is app-postgres-restore (the policies allow it)" '[ "$(yq ".metadata.name" "${WORK}/out.yaml")" = app-postgres-restore ]'
check "no recoveryTarget without -t" '[ "$(yq ".spec.bootstrap.recovery.recoveryTarget" "${WORK}/out.yaml")" = null ]'
check "default context is kind" 'grep -q -- "--context kind-sre-control-plane" "${STUB_LOG}"'

run -n develop -c some-ctx -t 2026-10-05T09:30:00Z
check "point in time: targetTime set" '[ "$(yq ".spec.bootstrap.recovery.recoveryTarget.targetTime" "${WORK}/out.yaml")" = 2026-10-05T09:30:00Z ]'
check "-c names the context of every call" '! grep -qv -- "--context some-ctx" "${STUB_LOG}"'

run -n develop -t yesterday
check "a time that is not RFC 3339 is refused (exit 2)" '[ "${RC}" = 2 ]'

run
check "missing -n is refused" '[ "${RC}" != 0 ]'

run -n develop -t
check "-t without a value is refused: exit 1, says why" '[ "${RC}" = 1 ] && grep -q -- "-t needs a value" "${WORK}/err.txt"'

run -n -c some-ctx
check "an option where a value belongs is refused: exit 1, says why" '[ "${RC}" = 1 ] && grep -q -- "-n needs a value" "${WORK}/err.txt"'

STUB_NO_BUCKET=1 run -n develop
check "a Secret without BUCKET fails loudly" '[ "${RC}" != 0 ]'

exit "${FAILED}"

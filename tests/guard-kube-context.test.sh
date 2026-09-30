#!/usr/bin/env bash
# Tests scripts/guard-kube-context.sh against a FAKE kubectl and flux - no cluster is touched.
# Run: tests/guard-kube-context.test.sh   (pre-commit runs it when the guard changes)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="${ROOT}/scripts/guard-kube-context.sh"
FAKE="$(mktemp -d)"
trap 'rm -rf "${FAKE}"' EXIT

# Fake kubectl/flux: contexts ctx-a and ctx-b exist, namespace "develop" exists in
# both, the current context is $FAKE_CURRENT. Any other call prints what it got.
cat > "${FAKE}/kubectl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "config get-contexts ctx-a"|"config get-contexts ctx-b") exit 0 ;;
  "config get-contexts "*) exit 1 ;;
  "config current-context") echo "${FAKE_CURRENT:-ctx-b}"; exit 0 ;;
  "--context ctx-a get namespace develop"|"--context ctx-b get namespace develop"|"get namespace develop") exit 0 ;;
  *"get namespace "*) exit 1 ;;
esac
echo "RAN: $(basename "$0") $*"
EOF
chmod +x "${FAKE}/kubectl"
cp "${FAKE}/kubectl" "${FAKE}/flux"
export PATH="${FAKE}:${PATH}"

FAILED=0
# expect <name> <exit code> <text the output must contain> -- <command...>
expect() {
  local name="$1" want_rc="$2" want_text="$3"
  shift 4
  local out rc=0
  out="$("$@" 2>&1)" || rc=$?
  if [[ "${rc}" -eq "${want_rc}" && "${out}" == *"${want_text}"* ]]; then
    echo "ok   ${name}"
  else
    echo "FAIL ${name}: exit ${rc} (want ${want_rc}), output:" >&2
    printf '%s\n' "${out}" >&2
    FAILED=1
  fi
}

# The race from Chapter 01: the current context was switched to ctx-b, but the
# pinned command still goes to ctx-a.
expect "pinned kubectl ignores the current context" 0 "RAN: kubectl --context ctx-a --namespace develop apply -f app.yaml" \
  -- env FAKE_CURRENT=ctx-b "${GUARD}" --context ctx-a --namespace develop -- kubectl apply -f app.yaml
expect "pinned flux" 0 "RAN: flux --context ctx-a --namespace develop get kustomizations" \
  -- "${GUARD}" --context ctx-a --namespace develop -- flux get kustomizations
expect "unknown context" 1 "context 'ctx-x' not found" \
  -- "${GUARD}" --context ctx-x --namespace develop -- kubectl apply -f app.yaml
expect "missing namespace" 1 "namespace 'nope' not found" \
  -- "${GUARD}" --context ctx-a --namespace nope -- kubectl apply -f app.yaml
expect "command with its own --context" 2 "sets its own target (--context)" \
  -- "${GUARD}" --context ctx-a --namespace develop -- kubectl --context ctx-b apply -f app.yaml
expect "command with its own -n" 2 "sets its own target (-n)" \
  -- "${GUARD}" --context ctx-a --namespace develop -- kubectl apply -n prod -f app.yaml
expect "command with -nprod" 2 "sets its own target (-nprod)" \
  -- "${GUARD}" --context ctx-a --namespace develop -- kubectl apply -nprod -f app.yaml
expect "command with -A" 2 "sets its own target (-A)" \
  -- "${GUARD}" --context ctx-a --namespace develop -- kubectl delete pods -A --all
expect "only kubectl and flux" 2 "only kubectl and flux can be pinned" \
  -- "${GUARD}" --context ctx-a --namespace develop -- helm upgrade x
expect "check-only, current matches" 0 "OK context=ctx-a" \
  -- env FAKE_CURRENT=ctx-a "${GUARD}" --context ctx-a --namespace develop
expect "check-only, current differs" 1 "context mismatch" \
  -- env FAKE_CURRENT=ctx-b "${GUARD}" --context ctx-a --namespace develop
expect "namespace is required" 2 "--context and --namespace are required" \
  -- "${GUARD}" --context ctx-a -- kubectl get pods

exit "${FAILED}"

#!/usr/bin/env bash
# Tests infra/terraform/kind_cluster/scripts/merge-kubeconfig.sh with a throw-away HOME - your real
# ~/.kube/config is never read or written, and no cluster is touched (kubectl only edits files).
# Run: tests/merge-kubeconfig.test.sh   (pre-commit runs it when the script changes)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="${ROOT}/infra/terraform/kind_cluster/scripts/merge-kubeconfig.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
export HOME="${TMP}/home"
mkdir -p "${HOME}/.kube"

FAILED=0
check() { # check <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then echo "ok   - $1"; else echo "FAIL - $1: expected '$2', got '$3'"; FAILED=1; fi
}
view() { kubectl config view --raw --kubeconfig "${HOME}/.kube/config" -o jsonpath="$1"; }

# ~/.kube/config before a rebuild: another cluster is the current context, and a STALE entry
# of the kind cluster (old server port, old token) is still there.
cat > "${HOME}/.kube/config" <<'EOF'
apiVersion: v1
kind: Config
current-context: other
clusters:
- name: other
  cluster: {server: "https://other.example:6443", certificate-authority: other-ca.crt}
- name: kind-sre-control-plane
  cluster: {server: "https://127.0.0.1:1111"}
users:
- name: other
  user: {token: other-token}
- name: kind-sre-control-plane
  user: {token: OLD-token}
contexts:
- name: other
  context: {cluster: other, user: other}
- name: kind-sre-control-plane
  context: {cluster: kind-sre-control-plane, user: kind-sre-control-plane}
EOF

# The other cluster's CA is a file next to the config, referenced by a RELATIVE path - kubectl
# resolves it from the config's directory, so the merge must not move the config elsewhere.
printf 'OTHER-CA\n' > "${HOME}/.kube/other-ca.crt"

# The kubeconfig the rebuilt cluster wrote.
cat > "${TMP}/new.yaml" <<'EOF'
apiVersion: v1
kind: Config
current-context: kind-sre-control-plane
clusters:
- name: kind-sre-control-plane
  cluster: {server: "https://127.0.0.1:6443"}
users:
- name: kind-sre-control-plane
  user: {token: NEW-token}
contexts:
- name: kind-sre-control-plane
  context: {cluster: kind-sre-control-plane, user: kind-sre-control-plane}
EOF

"${MERGE}" "${TMP}/new.yaml"

check "kind cluster entry is the new one" "https://127.0.0.1:6443" "$(view '{.clusters[?(@.name=="kind-sre-control-plane")].cluster.server}')"
check "kind user entry is the new one" "NEW-token" "$(view '{.users[?(@.name=="kind-sre-control-plane")].user.token}')"
check "current context is not switched" "other" "$(view '{.current-context}')"
check "other cluster is kept" "https://other.example:6443" "$(view '{.clusters[?(@.name=="other")].cluster.server}')"
check "one kind context, not two" "1" "$(view '{.contexts[*].name}' | tr ' ' '\n' | grep -cx 'kind-sre-control-plane')"
check "file is private (0600)" "${HOME}/.kube/config" "$(find "${HOME}/.kube/config" -perm 600)"
check "relative CA path of another cluster still resolves" "OTHER-CA" "$(view '{.clusters[?(@.name=="other")].cluster.certificate-authority-data}' | base64 -d)"
check "no temp copy left next to the config" "" "$(find "${HOME}/.kube" -name 'config.merge.*')"

# First run: no ~/.kube/config yet - the new file is taken as it is.
rm "${HOME}/.kube/config"
"${MERGE}" "${TMP}/new.yaml"
check "no previous config: new file is used" "NEW-token" "$(view '{.users[?(@.name=="kind-sre-control-plane")].user.token}')"

exit "${FAILED}"

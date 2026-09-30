#!/usr/bin/env bash
# Tests scripts/agent-hooks/kube-context-hook.sh - it only reads text, no cluster is touched.
# Run: tests/kube-context-hook.test.sh   (pre-commit runs it when the hook changes)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="${ROOT}/scripts/agent-hooks/kube-context-hook.sh"
FAILED=0

# check <allow|block> <command text>
check() {
  local want="$1" cmd="$2" rc=0
  printf '%s' "${cmd}" | "${HOOK}" >/dev/null 2>&1 || rc=$?
  local got="allow"
  [[ "${rc}" -eq 2 ]] && got="block"
  if [[ "${rc}" -ne 0 && "${rc}" -ne 2 ]]; then got="error(${rc})"; fi
  if [[ "${got}" == "${want}" ]]; then
    echo "ok   ${want}: ${cmd}"
  else
    echo "FAIL want ${want}, got ${got}: ${cmd}" >&2
    FAILED=1
  fi
}

# The incident: an agent switches the shared current context.
check block "kubectl config use-context prod"
check block "kubectl config set-context --current --namespace=production"
check block "kubectl config delete-context old"
check block "cd infra && kubectl config use-context prod"

# Commands that talk to a cluster must name it.
check block "kubectl apply -f app.yaml"
check block "kubectl -n develop get pods"
check block "flux get kustomizations"
check block "kubectl get pods --context kind-sre-control-plane | grep backend; kubectl delete pod x"
check block "KUBECONFIG=other.yaml kubectl get ns"
check block "/usr/local/bin/kubectl get ns"

# config set / use change the shared kubeconfig even with --context.
check block "kubectl --context kind-sre-control-plane config set current-context prod"
check block "kubectl --context kind-sre-control-plane config use prod"

# Tabs are whitespace too.
check block "$(printf 'kubectl\tget\tns')"
check block "$(printf 'flux\tget\tkustomizations')"

# An empty --context means the current context.
check block "kubectl --context= get ns"
check block 'kubectl --context "" get ns'
check block "kubectl --context '' get ns"

# kubectl takes the last --context: a second, empty one would win.
check block 'kubectl --context kind-sre-control-plane --context "" get ns'
check block "kubectl --context=kind-sre-control-plane --context= get ns"
check block "kubectl --context kind-sre-control-plane get ns --context other"

check allow "$(printf 'kubectl\t--context\tkind-sre-control-plane\tget\tns')"
check allow "kubectl --context kind-sre-control-plane -n develop get pods"
check allow "kubectl get pods --context=kind-sre-control-plane -n develop"
check allow "flux --context kind-sre-control-plane get kustomizations"
check allow "kubectl get pods --context kind-sre-control-plane | grep backend"
check allow "scripts/guard-kube-context.sh --context kind-sre-control-plane --namespace develop -- kubectl apply -f app.yaml"

# Reading the kubeconfig or the client version needs no cluster.
check allow "kubectl config get-contexts"
check allow "kubectl config current-context"
check allow "kubectl version --client"

# Not kubectl or flux: none of the hook's business.
check allow "git status && terraform plan"
check allow "echo kubectl apply is dangerous"

exit "${FAILED}"

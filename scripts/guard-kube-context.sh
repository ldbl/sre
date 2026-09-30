#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage:
  scripts/guard-kube-context.sh --context <name> --namespace <name> [--kubeconfig <path>] -- <kubectl|flux> <args...>
  scripts/guard-kube-context.sh --context <name> --namespace <name> [--kubeconfig <path>]

With a command after `--` (use this for every write): checks that the context
exists and the namespace exists in it, then runs the command with
`--context <name> --namespace <name>` added. The command never reads the
current context, so nobody - another terminal, an AI agent - can switch it
between the check and the write.

Without a command: only checks that the CURRENT context and namespace are the
expected ones. That is a check-then-act: the current context is one line in a
shared kubeconfig file and can change before your next command runs.

Examples:
  scripts/guard-kube-context.sh --context kind-sre-control-plane --namespace develop -- kubectl apply -f app.yaml
  scripts/guard-kube-context.sh --context kind-sre-control-plane --namespace flux-system -- flux get kustomizations
  scripts/guard-kube-context.sh --context kind-sre-control-plane --namespace develop
EOF
}

EXPECTED_CONTEXT=""
EXPECTED_NAMESPACE=""
KUBECONFIG_PATH=""
COMMAND=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      EXPECTED_CONTEXT="${2:-}"
      shift 2
      ;;
    --namespace)
      EXPECTED_NAMESPACE="${2:-}"
      shift 2
      ;;
    --kubeconfig)
      KUBECONFIG_PATH="${2:-}"
      shift 2
      ;;
    --)
      shift
      COMMAND=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[guard-kube] unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${EXPECTED_CONTEXT}" || -z "${EXPECTED_NAMESPACE}" ]]; then
  echo "[guard-kube] --context and --namespace are required" >&2
  usage >&2
  exit 2
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[guard-kube] kubectl not found in PATH" >&2
  exit 1
fi

if [[ -n "${KUBECONFIG_PATH}" ]]; then
  export KUBECONFIG="${KUBECONFIG_PATH}"
fi

# --- Pinned mode: check the named context, then run the command with it. ---
if [[ ${#COMMAND[@]} -gt 0 ]]; then
  TOOL="$(basename "${COMMAND[0]}")"
  # Only tools that take --context and --namespace, so the pin always applies.
  if [[ "${TOOL}" != "kubectl" && "${TOOL}" != "flux" ]]; then
    echo "[guard-kube] only kubectl and flux can be pinned, got: ${COMMAND[0]}" >&2
    exit 2
  fi
  # The guard sets the target; a second one inside the command would be
  # ambiguous (which one wins depends on the tool), so refuse it.
  for arg in "${COMMAND[@]:1}"; do
    case "${arg}" in
      --context|--context=*|--kubeconfig|--kubeconfig=*|-n|-n?*|--namespace|--namespace=*|-A|--all-namespaces|--all-namespaces=*)
        echo "[guard-kube] the command sets its own target (${arg}); give it only to the guard" >&2
        exit 2
        ;;
    esac
  done

  if ! kubectl config get-contexts "${EXPECTED_CONTEXT}" >/dev/null 2>&1; then
    echo "[guard-kube] context '${EXPECTED_CONTEXT}' not found in the kubeconfig" >&2
    exit 1
  fi
  if ! kubectl --context "${EXPECTED_CONTEXT}" get namespace "${EXPECTED_NAMESPACE}" >/dev/null 2>&1; then
    echo "[guard-kube] namespace '${EXPECTED_NAMESPACE}' not found in context '${EXPECTED_CONTEXT}'" >&2
    exit 1
  fi

  echo "[guard-kube] OK context=${EXPECTED_CONTEXT} namespace=${EXPECTED_NAMESPACE} - running ${TOOL} pinned to them" >&2
  exec "${COMMAND[0]}" --context "${EXPECTED_CONTEXT}" --namespace "${EXPECTED_NAMESPACE}" "${COMMAND[@]:1}"
fi

# --- Check-only mode: the current context must be the expected one. ---
CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
if [[ -z "${CURRENT_CONTEXT}" ]]; then
  echo "[guard-kube] no current kubectl context is set" >&2
  exit 1
fi

if [[ "${CURRENT_CONTEXT}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "[guard-kube] context mismatch" >&2
  echo "  expected: ${EXPECTED_CONTEXT}" >&2
  echo "  actual:   ${CURRENT_CONTEXT}" >&2
  exit 1
fi

if ! kubectl get namespace "${EXPECTED_NAMESPACE}" >/dev/null 2>&1; then
  echo "[guard-kube] namespace '${EXPECTED_NAMESPACE}' not found in context '${CURRENT_CONTEXT}'" >&2
  exit 1
fi

echo "[guard-kube] OK context=${CURRENT_CONTEXT} namespace=${EXPECTED_NAMESPACE}"
echo "[guard-kube] note: this only checked the current context; pass the command after -- to pin it" >&2

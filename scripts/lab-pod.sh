#!/usr/bin/env bash
# lab-pod.sh - run a one-off or long-lived test pod that the environment
# namespaces accept.
#
# develop/staging/production enforce Pod Security "restricted", so a plain
# `kubectl run busybox` is rejected before it starts. This wrapper adds the
# required securityContext, waits for the pod, prints its logs and returns its
# exit code - the labs use it instead of hand-written overrides.
#
# Usage:
#   scripts/lab-pod.sh -n <namespace> [-c <context>] [-i <image>] [-l key=value]... [-u <uid>] [-s <secret>] -- <command...>
#   scripts/lab-pod.sh -n <namespace> [-c <context>] [-i <image>] [-l key=value]... --daemon [<name>]
#
# Examples:
#   # probe the backend the way the frontend does (app=frontend passes the NetworkPolicies)
#   scripts/lab-pod.sh -n develop -i curlimages/curl:8.22.0 -l app=frontend -- curl -sf -m 5 http://backend/healthz
#   # long-lived debug pod, then: kubectl --context kind-sre-control-plane -n develop exec np-debug -- nc -w 2 backend 80
#   scripts/lab-pod.sh -n develop --daemon np-debug
#   # connect as the app, its password never on a command line (-s: every key as $SECRET_<key>)
#   scripts/lab-pod.sh -n develop -l app=backend -i postgres:17 -u 999 -s app-postgres-app -- \
#     sh -c 'PGPASSWORD="$SECRET_password" psql -h app-postgres-rw -U app -d app -c "SELECT 1"'
#
# Defaults: image busybox:1.36, uid 65532, read-only root filesystem with a
# writable /tmp (16Mi); CPU and memory come from the namespace LimitRange
# defaults. Pods are deleted after a one-off run; --daemon pods stay until
# you delete them.
#
# The cluster: -c, else $KUBE_CONTEXT, else kind-sre-control-plane. Every kubectl call names it
# (--context) - the pod is created and deleted there, never on the shared current context (Chapter 01).
#
# (Lines 2-29 above are also the --help text: usage() prints them. Keep notes for readers below.)
# Run by hand in the labs (Chapter 00 on). Needs: kubectl and jq.
# Images (-i): in develop/staging/production the Kyverno guardrails (Chapter 16) admit only a pinned
# tag (not latest, not none) from a trusted source - the platform registry, CloudNativePG, or the lab
# images busybox, postgres and curlimages/curl. Anything else is refused at `kubectl run`.
# Changes: creates one pod in the namespace; a one-off pod is deleted at the end, a --daemon pod stays.
# Exit code: the command's own; 124 when the pod did not finish within LAB_POD_TIMEOUT (default 120s).
set -euo pipefail

NAMESPACE=""
IMAGE="busybox:1.36"
UID_NUM="65532"
LABELS=()
SECRET=""
DAEMON=0
NAME=""
TIMEOUT="${LAB_POD_TIMEOUT:-120}"
CONTEXT="${KUBE_CONTEXT:-kind-sre-control-plane}"

# usage - print the header comment of this file (lines 2-29) as help, then exit 1.
usage() { sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

# need_value OPTION ARGS... - fail with a clear message when OPTION has no value after it, or when
# the "value" is the next option (-n -c ...). No namespace, image, label, Secret or context used here
# starts with "-", so a leading "-" always means a missing value.
need_value() {
  if [ $# -lt 2 ] || [ -z "$2" ] || [ "${2#-}" != "$2" ]; then echo "$1 needs a value" >&2; usage; fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n) need_value "$@"; NAMESPACE="$2"; shift 2 ;;
    -c) need_value "$@"; CONTEXT="$2"; shift 2 ;;
    -i) need_value "$@"; IMAGE="$2"; shift 2 ;;
    -l) need_value "$@"; LABELS+=("$2"); shift 2 ;;
    -u) need_value "$@"; UID_NUM="$2"; shift 2 ;;
    -s) need_value "$@"; SECRET="$2"; shift 2 ;;
    --daemon) DAEMON=1; shift; if [ $# -gt 0 ] && [ "$1" != "--" ]; then NAME="$1"; shift; fi ;;
    --) shift; break ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done
[ -n "$NAMESPACE" ] || { echo "-n <namespace> is required" >&2; usage; }
kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1 || { echo "context '$CONTEXT' not found in the kubeconfig (-c or KUBE_CONTEXT)" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "jq is required (make check-tools)" >&2; exit 2; }

# The only way this script talks to a cluster.
k() { kubectl --context "$CONTEXT" "$@"; }

if [ "$DAEMON" -eq 1 ]; then
  [ -n "$NAME" ] || NAME="lab-debug"
  # BusyBox sleep rejects "infinity"; loop on a duration every image accepts.
  CMD_JSON='["sh","-c","while true; do sleep 3600; done"]'
else
  [ $# -gt 0 ] || { echo "command after -- is required (or use --daemon)" >&2; usage; }
  NAME="lab-$(date +%s)-$RANDOM"
  # The command as a JSON array, each argument quoted by jq - no shell or JSON escaping by hand.
  # The arguments go in on stdin, NUL-separated: on jq's command line an argument such as "-c"
  # would be read as a jq option.
  CMD_JSON="$(printf '%s\0' "$@" | jq -cRs 'split("\u0000") | .[:-1]')"
fi

LABEL_JSON="{}"
if [ ${#LABELS[@]} -gt 0 ]; then
  # key=value pairs to a JSON object; the value may itself contain "=".
  LABEL_JSON="$(printf '%s\0' "${LABELS[@]}" | jq -cRs 'split("\u0000") | .[:-1] | map(capture("^(?<k>[^=]+)=(?<v>.*)$") | {(.k): .v}) | add // {}')"
fi

# -s: the Secret's keys as environment variables with the prefix SECRET_ (envFrom), so a password
# reaches the command without appearing in it, in the pod spec or in the shell history.
ENV_FROM_JSON="[]"
if [ -n "$SECRET" ]; then
  ENV_FROM_JSON="$(jq -cn --arg s "$SECRET" '[{"prefix": "SECRET_", "secretRef": {"name": $s}}]')"
fi

# The pod spec kubectl run cannot express with flags: everything Pod Security "restricted" requires
# (non-root user, no privilege escalation, no capabilities, RuntimeDefault seccomp) plus a read-only
# root filesystem with a writable /tmp, capped at 16Mi like every emptyDir on the platform.
OVERRIDES="$(cat <<JSON
{
  "metadata": {"labels": ${LABEL_JSON}},
  "spec": {
    "restartPolicy": "Never",
    "securityContext": {
      "runAsNonRoot": true,
      "runAsUser": ${UID_NUM},
      "runAsGroup": ${UID_NUM},
      "seccompProfile": {"type": "RuntimeDefault"}
    },
    "containers": [{
      "name": "${NAME}",
      "image": "${IMAGE}",
      "command": ${CMD_JSON},
      "envFrom": ${ENV_FROM_JSON},
      "securityContext": {
        "runAsNonRoot": true,
        "allowPrivilegeEscalation": false,
        "readOnlyRootFilesystem": true,
        "capabilities": {"drop": ["ALL"]}
      },
      "volumeMounts": [{"name": "tmp", "mountPath": "/tmp"}]
    }],
    "volumes": [{"name": "tmp", "emptyDir": {"sizeLimit": "16Mi"}}]
  }
}
JSON
)"

k -n "$NAMESPACE" run "$NAME" --image="$IMAGE" --restart=Never --overrides="$OVERRIDES" >/dev/null

# --daemon: wait until the pod is Ready and print its name, for kubectl exec.
if [ "$DAEMON" -eq 1 ]; then
  k -n "$NAMESPACE" wait --for=condition=Ready "pod/$NAME" --timeout="${TIMEOUT}s" >/dev/null
  echo "$NAME"
  exit 0
fi

# One-off: poll once a second until the pod has finished (Succeeded or Failed), up to TIMEOUT.
phase=""
for _ in $(seq 1 "$TIMEOUT"); do
  phase="$(k -n "$NAMESPACE" get pod "$NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  case "$phase" in Succeeded|Failed) break ;; esac
  sleep 1
done

# Print the output, keep the container's exit code, then delete the pod (without waiting for it).
k -n "$NAMESPACE" logs "$NAME" 2>/dev/null || true
exit_code="$(k -n "$NAMESPACE" get pod "$NAME" -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}' 2>/dev/null || echo 1)"
k -n "$NAMESPACE" delete pod "$NAME" --wait=false >/dev/null 2>&1 || true

if [ "$phase" != "Succeeded" ] && [ "$phase" != "Failed" ]; then
  echo "lab-pod: timed out after ${TIMEOUT}s (phase=${phase:-unknown})" >&2
  exit 124
fi
exit "${exit_code:-1}"

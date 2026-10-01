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
#   scripts/lab-pod.sh -n <namespace> [-c <context>] [-i <image>] [-l key=value]... [-u <uid>] [-m <memory>] -- <command...>
#   scripts/lab-pod.sh -n <namespace> [-c <context>] [-i <image>] [-l key=value]... --daemon [<name>]
#
# Examples:
#   # probe the backend the way the frontend does (app=frontend passes the NetworkPolicies)
#   scripts/lab-pod.sh -n develop -i curlimages/curl -l app=frontend -- curl -sf -m 5 http://backend/healthz
#   # long-lived debug pod, then: kubectl --context kind-sre-control-plane -n develop exec np-debug -- nc -w 2 backend 80
#   scripts/lab-pod.sh -n develop --daemon np-debug
#
# Defaults: image busybox:1.36, uid 65532, read-only root filesystem with a
# writable /tmp. -m sets memory request = limit (e.g. -m 64Mi for an OOM
# drill); otherwise the namespace LimitRange defaults apply. Pods are deleted after a one-off run; --daemon pods stay until
# you delete them.
#
# The cluster: -c, else $KUBE_CONTEXT, else kind-sre-control-plane. Every kubectl call names it
# (--context) - the pod is created and deleted there, never on the shared current context (Chapter 01).
set -euo pipefail

NAMESPACE=""
IMAGE="busybox:1.36"
UID_NUM="65532"
MEMORY=""
LABELS=()
DAEMON=0
NAME=""
TIMEOUT="${LAB_POD_TIMEOUT:-120}"
CONTEXT="${KUBE_CONTEXT:-kind-sre-control-plane}"

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n) NAMESPACE="$2"; shift 2 ;;
    -c) CONTEXT="$2"; shift 2 ;;
    -i) IMAGE="$2"; shift 2 ;;
    -l) LABELS+=("$2"); shift 2 ;;
    -u) UID_NUM="$2"; shift 2 ;;
    -m) MEMORY="$2"; shift 2 ;;
    --daemon) DAEMON=1; shift; if [ $# -gt 0 ] && [ "$1" != "--" ]; then NAME="$1"; shift; fi ;;
    --) shift; break ;;
    -h|--help) usage ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done
[ -n "$NAMESPACE" ] || { echo "-n <namespace> is required" >&2; usage; }
kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1 || { echo "context '$CONTEXT' not found in the kubeconfig (-c or KUBE_CONTEXT)" >&2; exit 2; }

# The only way this script talks to a cluster.
k() { kubectl --context "$CONTEXT" "$@"; }

if [ "$DAEMON" -eq 1 ]; then
  [ -n "$NAME" ] || NAME="lab-debug"
  # BusyBox sleep rejects "infinity"; loop on a duration every image accepts.
  CMD_JSON='["sh","-c","while true; do sleep 3600; done"]'
else
  [ $# -gt 0 ] || { echo "command after -- is required (or use --daemon)" >&2; usage; }
  NAME="lab-$(date +%s)-$RANDOM"
  CMD_JSON="$(printf '%s\n' "$@" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().split("\n")[:-1]))')"
fi

RESOURCES_JSON="{}"
if [ -n "$MEMORY" ]; then
  RESOURCES_JSON="{\"requests\": {\"memory\": \"${MEMORY}\"}, \"limits\": {\"memory\": \"${MEMORY}\"}}"
fi

LABEL_JSON="{}"
if [ ${#LABELS[@]} -gt 0 ]; then
  LABEL_JSON="$(printf '%s\n' "${LABELS[@]}" | python3 -c 'import json,sys; print(json.dumps(dict(l.split("=",1) for l in sys.stdin.read().split("\n") if l)))')"
fi

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
      "resources": ${RESOURCES_JSON},
      "securityContext": {
        "runAsNonRoot": true,
        "allowPrivilegeEscalation": false,
        "readOnlyRootFilesystem": true,
        "capabilities": {"drop": ["ALL"]}
      },
      "volumeMounts": [{"name": "tmp", "mountPath": "/tmp"}]
    }],
    "volumes": [{"name": "tmp", "emptyDir": {}}]
  }
}
JSON
)"

k -n "$NAMESPACE" run "$NAME" --image="$IMAGE" --restart=Never --overrides="$OVERRIDES" >/dev/null

if [ "$DAEMON" -eq 1 ]; then
  k -n "$NAMESPACE" wait --for=condition=Ready "pod/$NAME" --timeout="${TIMEOUT}s" >/dev/null
  echo "$NAME"
  exit 0
fi

phase=""
for _ in $(seq 1 "$TIMEOUT"); do
  phase="$(k -n "$NAMESPACE" get pod "$NAME" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  case "$phase" in Succeeded|Failed) break ;; esac
  sleep 1
done

k -n "$NAMESPACE" logs "$NAME" 2>/dev/null || true
exit_code="$(k -n "$NAMESPACE" get pod "$NAME" -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}' 2>/dev/null || echo 1)"
k -n "$NAMESPACE" delete pod "$NAME" --wait=false >/dev/null 2>&1 || true

if [ "$phase" != "Succeeded" ] && [ "$phase" != "Failed" ]; then
  echo "lab-pod: timed out after ${TIMEOUT}s (phase=${phase:-unknown})" >&2
  exit 124
fi
exit "${exit_code:-1}"

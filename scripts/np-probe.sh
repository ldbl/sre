#!/usr/bin/env bash
# np-probe.sh - is a connection allowed? Answers the two questions separately: does the name
# resolve (DNS), and does a TCP connection to the port open?
#
# "nc ... && echo OPEN || echo BLOCKED" mixes them up: a name that does not resolve, a Service
# without endpoints and a NetworkPolicy all print BLOCKED. This probe prints both answers, so a
# blocked connection with working DNS points at the rules - and a failing DNS lookup does not.
#
# Usage: scripts/np-probe.sh -n <namespace> [-c <context>] [-l key=value]... <host> <port>
#   -n  the namespace the probe pod runs in (its NetworkPolicies apply to it)
#   -l  labels of the probe pod - the "identity" NetworkPolicies select (repeatable)
#   -c  the cluster: -c, else $KUBE_CONTEXT, else kind-sre-control-plane
# Example: scripts/np-probe.sh -n develop -l app=frontend backend 80
#
# Output, one line: "DNS ok (10.96.1.73), TCP open" | "DNS ok (...), TCP blocked" | "DNS FAILED".
# Exit code: 0 TCP open, 1 TCP blocked, 2 DNS failed, 3 usage error.
# Runs a one-off pod through scripts/lab-pod.sh (Pod Security restricted, deleted afterwards).
# Changes nothing else. Needs kubectl and jq (for lab-pod.sh). Chapter 06.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE=""
CONTEXT="${KUBE_CONTEXT:-kind-sre-control-plane}"
LABEL_ARGS=()

# usage - print the header comment (lines 2-18) as help, then exit 3.
usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 3; }

while [ $# -gt 0 ]; do
  case "$1" in
    -n) NAMESPACE="$2"; shift 2 ;;
    -c) CONTEXT="$2"; shift 2 ;;
    -l) LABEL_ARGS+=(-l "$2"); shift 2 ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) break ;;
  esac
done
[ -n "${NAMESPACE}" ] && [ $# -eq 2 ] || usage
HOST="$1"
PORT="$2"

# Inside the pod (busybox): resolve first and stop there if it fails; then try TCP to the port.
# The exit code carries the answer out of the pod - lab-pod.sh returns the command's own.
# shellcheck disable=SC2016  # expanded by the shell inside the pod
PROBE='
ip="$(nslookup "$0" 2>/dev/null | awk "/^Name:/ {n=1} n && /^Address/ {print \$2; exit}")"
if [ -z "$ip" ]; then echo "DNS FAILED"; exit 2; fi
if nc -z -w 3 "$0" "$1" 2>/dev/null; then echo "DNS ok ($ip), TCP open"; exit 0; fi
echo "DNS ok ($ip), TCP blocked"; exit 1
'

rc=0
out="$("${SCRIPT_DIR}/lab-pod.sh" -c "${CONTEXT}" -n "${NAMESPACE}" ${LABEL_ARGS[@]+"${LABEL_ARGS[@]}"} \
  -- sh -c "${PROBE}" "${HOST}" "${PORT}" 2>&1)" || rc=$?
# lab-pod.sh prints the pod's log; the probe's verdict is its last line.
echo "${out}" | tail -1
exit "${rc}"

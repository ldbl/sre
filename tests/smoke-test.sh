#!/usr/bin/env bash
# Infrastructure smoke tests for the SRE platform.
# Validates a running cluster by checking core components.
#
# Requirements: kubectl, flux CLI, and KUBE_CONTEXT - the kubeconfig context
# of the cluster to test (`make smoke-test` sets kind-sre-control-plane).
# Every kubectl/flux call names that context: the test also creates and deletes a
# pod, and it must never land on whatever the shared current context is (Chapter 01).
# Exit codes: 0 = all pass, 1 = one or more failures, 2 = no or unknown context
# Output: TAP-like format (test name + pass/fail)
#
# Usage: make smoke-test   (or KUBE_CONTEXT=<context> bash tests/smoke-test.sh)
# Runs by hand as the baseline check of every chapter (Chapter 00), and in the Hetzner e2e workflow
# with KUBE_CONTEXT=hetzner-sre-control-plane.
# What it checks: Flux, the backend and frontend in develop, a request to the backend, the generated
# secrets, cert-manager Certificates and the CNPG clusters. It changes nothing in the cluster except
# one short-lived probe pod (smoke-curl-<time>-<random> in develop), which it deletes again.
set -Eeuo pipefail

KUBE_CONTEXT="${KUBE_CONTEXT:-}"
if [ -z "$KUBE_CONTEXT" ]; then
  echo "smoke-test: set KUBE_CONTEXT (make smoke-test uses kind-sre-control-plane)" >&2
  exit 2
fi
if ! kubectl config get-contexts "$KUBE_CONTEXT" >/dev/null 2>&1; then
  echo "smoke-test: context '$KUBE_CONTEXT' not found in the kubeconfig" >&2
  exit 2
fi
export KUBE_CONTEXT
echo "# cluster: $KUBE_CONTEXT"

# The only way this script talks to a cluster.
# k / f ARGS... - kubectl / flux against KUBE_CONTEXT.
k() { kubectl --context "$KUBE_CONTEXT" "$@"; }
f() { flux --context "$KUBE_CONTEXT" "$@"; }

PASS=0
FAIL=0
TOTAL=0

# pass NAME / fail NAME - count the result and print one TAP line.
pass() {
  TOTAL=$((TOTAL + 1))
  PASS=$((PASS + 1))
  echo "ok $TOTAL - $1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAIL=$((FAIL + 1))
  echo "not ok $TOTAL - $1"
}

# run_test NAME COMMAND... - run the command quietly; exit 0 is a pass, anything else a fail.
run_test() {
  local name="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    pass "$name"
  else
    fail "$name"
  fi
}

# --- 1. Flux health ---
run_test "Flux check passes" f check

# shellcheck disable=SC2016  # the inner shell expands the exported KUBE_CONTEXT
run_test "All Kustomizations are ready" \
  bash -c 'kubectl --context "$KUBE_CONTEXT" get kustomizations.kustomize.toolkit.fluxcd.io -n flux-system -o jsonpath="{.items[*].status.conditions[?(@.type==\"Ready\")].status}" | tr " " "\n" | grep -v True | wc -l | grep -q "^0$"'

# --- 2. Core deployments available ---
for deploy in frontend backend; do
  run_test "Deployment $deploy in develop is Available" \
    k rollout status deployment/"$deploy" -n develop --timeout=10s
done

# --- 3. Services reachable ---
# The backend Service listens on port 80 (targetPort http=8080).
# The probe pod carries app=frontend (develop is default-deny; only frontend
# and Traefik may reach the backend) and a restricted-PSS-compliant spec.
# No `--rm -i`: attaching to a pod that exits in <1s races and reports a
# timeout; create it, wait for completion, read the exit status, delete it.
# smoke_curl - true when the probe pod's curl to the backend's /healthz succeeded (waits up to 60s).
# The pod gets a unique name, so two runs never collide and no pod of anyone else is deleted.
smoke_curl() {
  local ns="develop" pod
  pod="smoke-curl-$(date +%s)-$RANDOM"
  k run "$pod" --image=curlimages/curl --labels=app=frontend --restart=Never -n "$ns" \
    --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":100,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"smoke-curl","image":"curlimages/curl","command":["curl","-sf","-m","10","http://backend.develop.svc.cluster.local/healthz"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}' >/dev/null
  local phase=""
  for _ in $(seq 1 30); do
    phase="$(k -n "$ns" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null)"
    [ "$phase" = "Succeeded" ] || [ "$phase" = "Failed" ] && break
    sleep 2
  done
  k -n "$ns" delete pod "$pod" --ignore-not-found --wait=false >/dev/null 2>&1
  [ "$phase" = "Succeeded" ]
}
run_test "Backend /healthz responds in develop" smoke_curl

# --- 4. Critical secrets present ---
# (uptrace-secrets is not part of flux/secrets/develop; the DSN lives in backend-secrets)
for secret in backend-secrets app-postgres-app; do
  run_test "Secret $secret exists in develop" \
    k get secret "$secret" -n develop
done

# --- 5. Certificates valid ---
# shellcheck disable=SC2016  # the inner shell expands the exported KUBE_CONTEXT
run_test "cert-manager Certificate resources are Ready" \
  bash -c 'kubectl --context "$KUBE_CONTEXT" get certificates -A -o jsonpath="{.items[*].status.conditions[?(@.type==\"Ready\")].status}" | tr " " "\n" | grep -v True | wc -l | grep -q "^0$"'

# --- 6. CNPG clusters healthy ---
# shellcheck disable=SC2016  # the inner shell expands the exported KUBE_CONTEXT
run_test "CNPG clusters are Running" \
  bash -c 'kubectl --context "$KUBE_CONTEXT" get clusters.postgresql.cnpg.io -A -o jsonpath="{range .items[*]}{.status.phase}{\"\\n\"}{end}" | grep -v "^Cluster in healthy state$" | grep -v "^$" | wc -l | grep -q "^0$"'

# --- Summary ---
echo ""
echo "# Tests: $TOTAL, Pass: $PASS, Fail: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

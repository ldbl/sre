#!/usr/bin/env bash
# One-time migration for an EXISTING cluster before spec.replicas leaves Git (the HPA owns it).
#
# Why: Flux applies with server-side apply. If kustomize-controller is the only owner of
# spec.replicas and the field disappears from Git, the API server resets it to the default 1 -
# production would drop from 2 to 1 until the HPA scales back up. Handing the field to another
# field manager first keeps the current value; after that Flux no longer touches it.
# Verified on kind 2026-09-27: sole owner removes the field -> 3 becomes 1; after a handover -> stays 3.
#
# A new cluster does not need this: its Deployments are created without replicas and the HPA
# scales them to minReplicas.
#
#   scripts/hpa-replicas-handover.sh kind-sre-control-plane            # dry run: show what it would do
#   scripts/hpa-replicas-handover.sh kind-sre-control-plane --apply    # do it
set -euo pipefail

context="${1:?usage: $0 KUBE_CONTEXT [--apply]}"
mode="${2:-dry-run}"
namespaces=(develop staging production)
field_manager="hpa-handover"

kube() { kubectl --context "${context}" "$@"; }

for ns in "${namespaces[@]}"; do
  # Only an absent namespace is skipped; any other error (no access, wrong context) stops the run.
  if ! found_ns="$(kube get namespace "${ns}" --ignore-not-found -o name)"; then
    echo "error: cannot read namespace ${ns}" >&2
    exit 1
  fi
  if [[ -z "${found_ns}" ]]; then
    echo "skip ${ns}: namespace not found"
    continue
  fi

  # Captured, not a process substitution: a failed lookup must stop the run, not look like "no HPAs".
  if ! hpas="$(kube -n "${ns}" get hpa -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.scaleTargetRef.kind}{"\t"}{.spec.scaleTargetRef.name}{"\n"}{end}')"; then
    echo "error: cannot list HPAs in ${ns}" >&2
    exit 1
  fi

  while IFS=$'\t' read -r hpa kind target; do
    [[ -z "${hpa}" ]] && continue
    if [[ "${kind}" != "Deployment" ]]; then
      echo "skip ${ns}/${hpa}: targets ${kind}, not a Deployment"
      continue
    fi
    if ! replicas="$(kube -n "${ns}" get deployment "${target}" --ignore-not-found -o jsonpath='{.spec.replicas}')"; then
      echo "error: cannot read deployment ${ns}/${target}" >&2
      exit 1
    fi
    if [[ -z "${replicas}" ]]; then
      echo "skip ${ns}/${target}: Deployment not found"
      continue
    fi

    if [[ "${mode}" != "--apply" ]]; then
      echo "would hand over ${ns}/${target} spec.replicas=${replicas} to ${field_manager}"
      continue
    fi
    kube apply --server-side --field-manager="${field_manager}" -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${target}
  namespace: ${ns}
spec:
  replicas: ${replicas}
EOF
    echo "handed over ${ns}/${target} spec.replicas=${replicas} to ${field_manager}"
  done <<<"${hpas}"
done

if [[ "${mode}" != "--apply" ]]; then
  echo "dry run - nothing changed. Re-run with --apply."
fi

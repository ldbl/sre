#!/usr/bin/env bash
# Merge the kind cluster's generated kubeconfig into ~/.kube/config.
#
# kubectl merges kubeconfig files in order, and for the same name the FIRST file wins. ~/.kube/config
# comes first, so that its current-context stays as it was (Chapter 01: nobody switches it). But after
# a rebuild it would then also keep the OLD cluster/user entries of this kind cluster - old
# certificates, and kubectl failing against the new cluster. So the entries this file brings
# (context, cluster, user) are removed from ~/.kube/config first; everything else stays untouched.
#
# Usage: merge-kubeconfig.sh <kubeconfig_path>
#   Called by null_resource.merge_kubeconfig (local-exec) in infra/terraform/kind_cluster/main.tf
#   with the kubeconfig kind wrote next to the module. Tested by tests/merge-kubeconfig.test.sh.
# Needs kubectl - it only edits kubeconfig files and talks to no cluster.
# Changes: ~/.kube/config (created if missing, mode 0600).
set -euo pipefail
NEW_KCFG=${1:-}
if [[ -z "$NEW_KCFG" || ! -f "$NEW_KCFG" ]]; then
  echo "usage: merge-kubeconfig.sh <kubeconfig_path>" >&2
  exit 1
fi
DEFAULT_KCFG="$HOME/.kube/config"
mkdir -p "$HOME/.kube"
TMP_MERGE="$(mktemp)"
if [[ -f "$DEFAULT_KCFG" ]]; then
  # Work on a copy, so a failure halfway never leaves ~/.kube/config half-edited.
  TMP_OLD="$(mktemp)"
  cp "$DEFAULT_KCFG" "$TMP_OLD"
  # names JSONPATH - the names (one per line) the new kubeconfig brings; existing JSONPATH - the same
  # names in the copy of the old one, so only entries that are really there get deleted.
  names() { kubectl config view --kubeconfig "$NEW_KCFG" -o jsonpath="$1" | tr ' ' '\n' | sed '/^$/d'; }
  existing() { kubectl config view --kubeconfig "$TMP_OLD" -o jsonpath="$1" | tr ' ' '\n'; }
  for ctx in $(names '{.contexts[*].name}'); do
    if existing '{.contexts[*].name}' | grep -qxF "$ctx"; then
      kubectl config delete-context "$ctx" --kubeconfig "$TMP_OLD" >/dev/null
    fi
  done
  for cl in $(names '{.clusters[*].name}'); do
    if existing '{.clusters[*].name}' | grep -qxF "$cl"; then
      kubectl config delete-cluster "$cl" --kubeconfig "$TMP_OLD" >/dev/null
    fi
  done
  for u in $(names '{.users[*].name}'); do
    if existing '{.users[*].name}' | grep -qxF "$u"; then
      kubectl config delete-user "$u" --kubeconfig "$TMP_OLD" >/dev/null
    fi
  done
  # Old config first, so its current-context wins; --flatten inlines the certificates.
  KUBECONFIG="$TMP_OLD:$NEW_KCFG" kubectl config view --flatten > "$TMP_MERGE"
  rm -f "$TMP_OLD"
else
  cp "$NEW_KCFG" "$TMP_MERGE"
fi
# Replace in one step (mv), so ~/.kube/config is never half-written.
mv "$TMP_MERGE" "$DEFAULT_KCFG"
chmod 600 "$DEFAULT_KCFG"

# The context keeps kind's own name, kind-<cluster>, e.g. kind-sre-control-plane.
# It is not renamed: a bare name is left for the Hetzner cluster.

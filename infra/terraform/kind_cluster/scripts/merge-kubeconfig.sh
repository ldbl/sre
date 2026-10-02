#!/usr/bin/env bash
# Merge the kind cluster's generated kubeconfig into ~/.kube/config.
#
# kubectl merges kubeconfig files in order, and for the same name the FIRST file wins. ~/.kube/config
# comes first, so that its current-context stays as it was (Chapter 01: nobody switches it). But after
# a rebuild it would then also keep the OLD cluster/user entries of this kind cluster - old
# certificates, and kubectl failing against the new cluster. So the entries this file brings
# (context, cluster, user) are removed from ~/.kube/config first; everything else stays untouched.
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
  # Work on a copy, so a failure halfway never leaves ~/.kube/config half-edited. The copy sits next
  # to the original: kubectl resolves relative certificate and key paths from the file's directory.
  TMP_OLD="$(mktemp "$HOME/.kube/config.merge.XXXXXX")"
  trap 'rm -f "$TMP_OLD" "$TMP_MERGE"' EXIT
  cp "$DEFAULT_KCFG" "$TMP_OLD"
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
  KUBECONFIG="$TMP_OLD:$NEW_KCFG" kubectl config view --flatten > "$TMP_MERGE"
  rm -f "$TMP_OLD"
else
  cp "$NEW_KCFG" "$TMP_MERGE"
fi
mv "$TMP_MERGE" "$DEFAULT_KCFG"
chmod 600 "$DEFAULT_KCFG"

# The context keeps kind's own name, kind-<cluster>, e.g. kind-sre-control-plane.
# It is not renamed: a bare name is left for the Hetzner cluster.

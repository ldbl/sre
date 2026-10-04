#!/usr/bin/env bash
# check-image-tags.sh - every app overlay deploys a tag its own environment's ImagePolicy would pick.
#
# Why: the image tag of each environment lives in the overlay's kustomization.yaml (images[].newTag),
# followed by a setter comment such as # {"$imagepolicy": "production:backend:tag"}. Flux image
# automation (Hetzner) rewrites that line - and only that line - when the ImagePolicy picks a newer
# tag. Two hand edits break it quietly:
#   - a tag from another environment, or a malformed one (staging-... in production): the cluster runs
#     an image the policy would never have chosen - an untested build, or a build for another
#     environment;
#   - a missing or wrong setter comment: automation no longer updates the environment, and nothing
#     says so.
# For every app overlay this check reads the sibling image-policy.yaml and fails when newTag does not
# match its filterTags.pattern, or when the setter comment does not name that policy
# ("<namespace>:<name>:tag").
#
# Runs in pre-commit (and with it in the CI `hooks` job). Needs yq (v4).
# Usage: scripts/check-image-tags.sh   (no arguments; reads the overlays under flux/apps)
# Read-only: changes no file and no cluster. Exit 0 when every overlay passes, 1 otherwise.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

command -v yq >/dev/null || { echo "check-image-tags: yq is required (make check-tools)" >&2; exit 1; }

failures=()
checked=0

# Every overlay that sets an image tag; its ImagePolicy sits next to it.
while IFS= read -r kustomization; do
  dir="$(dirname "${kustomization}")"
  policy="${dir}/image-policy.yaml"
  if [[ ! -f "${policy}" ]]; then
    failures+=("${kustomization}: sets newTag but has no image-policy.yaml next to it")
    continue
  fi

  tag="$(yq '.images[0].newTag' "${kustomization}")"
  setter="$(yq '.images[0].newTag | line_comment' "${kustomization}")"
  pattern="$(yq '.spec.filterTags.pattern' "${policy}")"
  policy_ref="$(yq '.metadata.namespace + ":" + .metadata.name' "${policy}")"

  # The ImagePolicy pattern uses a named group, (?P<ts>...), for Flux; bash regex (ERE) has only plain
  # groups, so drop the name - what the pattern accepts stays the same.
  ere="${pattern//\(\?P<[a-z]*>/(}"

  if [[ ! "${tag}" =~ ${ere} ]]; then
    failures+=("${kustomization}: newTag '${tag}' does not match ${policy} (${pattern})")
  fi
  expected_setter="{\"\$imagepolicy\": \"${policy_ref}:tag\"}"
  if [[ "${setter}" != "${expected_setter}" ]]; then
    failures+=("${kustomization}: the newTag line must end with # ${expected_setter} (got: '${setter}')")
  fi
  checked=$((checked + 1))
done < <(grep -l 'newTag:' flux/apps/*/*/kustomization.yaml flux/apps/*/overlays/*/kustomization.yaml 2>/dev/null | sort)

if [[ "${checked}" -eq 0 && ${#failures[@]} -eq 0 ]]; then
  echo "check-image-tags: no overlay with newTag found under flux/apps" >&2
  exit 1
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "check-image-tags: ${#failures[@]} problem(s):" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-image-tags: OK (${checked} overlays)"

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
# For every images[] entry with a newTag, this check finds the ImagePolicy of the same name, in the same
# directory and in the overlay's namespace, and fails when newTag does not match its filterTags.pattern, or when the setter comment does
# not name that policy ("<namespace>:<name>:tag").
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

# Every kustomization.yaml under flux/apps, parsed with yq (not grepped: `newTag :` is valid YAML too).
# Each images[] entry with a newTag is checked against the ImagePolicy in the same directory that has
# the image's name (backend -> backend) and sits in the overlay's own namespace (production -> production).
while IFS= read -r kustomization; do
  dir="$(dirname "${kustomization}")"
  count="$(yq '.images | length' "${kustomization}")"
  namespace="$(yq '.namespace' "${kustomization}")"
  for ((i = 0; i < count; i++)); do
    [[ "$(yq ".images[${i}] | has(\"newTag\")" "${kustomization}")" == "true" ]] || continue  # a rename sets no tag
    name="$(yq ".images[${i}].name" "${kustomization}")"
    tag="$(yq ".images[${i}].newTag" "${kustomization}")"
    setter="$(yq ".images[${i}].newTag | line_comment" "${kustomization}")"
    if [[ "${namespace}" == "null" ]]; then
      failures+=("${kustomization}: image '${name}' sets newTag but the overlay sets no namespace (its environment)")
      continue
    fi

    # The policy for this image: an ImagePolicy named like the image, in the overlay's namespace.
    select_policy="select(.kind == \"ImagePolicy\" and .metadata.name == \"${name}\" and .metadata.namespace == \"${namespace}\")"
    policy=""
    for candidate in "${dir}"/*.yaml; do
      if [[ "$(yq ea "${select_policy} | .metadata.name" "${candidate}")" == "${name}" ]]; then
        policy="${candidate}"
        break
      fi
    done
    if [[ -z "${policy}" ]]; then
      failures+=("${kustomization}: image '${name}' sets newTag but ${dir} has no ImagePolicy '${name}' in namespace '${namespace}'")
      continue
    fi

    pattern="$(yq ea "${select_policy} | .spec.filterTags.pattern" "${policy}")"
    policy_ref="${namespace}:${name}"

    # The ImagePolicy pattern uses a named group, (?P<ts>...), for Flux; bash regex (ERE) has only plain
    # groups, so drop the name - what the pattern accepts stays the same.
    ere="${pattern//\(\?P<[a-z]*>/(}"

    if [[ ! "${tag}" =~ ${ere} ]]; then
      failures+=("${kustomization}: image '${name}' newTag '${tag}' does not match ${policy} (${pattern})")
    fi
    expected_setter="{\"\$imagepolicy\": \"${policy_ref}:tag\"}"
    if [[ "${setter}" != "${expected_setter}" ]]; then
      failures+=("${kustomization}: image '${name}': the newTag line must end with # ${expected_setter} (got: '${setter}')")
    fi
    checked=$((checked + 1))
  done
done < <(find flux/apps -name kustomization.yaml | sort)

if [[ "${checked}" -eq 0 && ${#failures[@]} -eq 0 ]]; then
  echo "check-image-tags: no overlay with newTag found under flux/apps" >&2
  exit 1
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo "check-image-tags: ${#failures[@]} problem(s):" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-image-tags: OK (${checked} image tags)"

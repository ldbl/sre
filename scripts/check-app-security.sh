#!/usr/bin/env bash
# Guardrail for the app manifests (security review 2026-09-27). Renders every backend and frontend
# overlay and fails when a rule is broken:
#   - every Deployment: automountServiceAccountToken: false (the apps never call the Kubernetes API)
#   - backend: PPROF_ENABLED is "false" everywhere (profiling is turned on by hand, never in Git)
#   - backend: CHAOS_ENABLED is exactly "true" in develop and staging (the chaos labs need it) and
#     "false" in production
#   - every overlay renders at least one Deployment (an empty render must not pass as OK)
#   - a Deployment targeted by an HPA sets no spec.replicas (the HPA owns the count; a value in Git
#     makes Flux reset what the HPA scaled on every reconcile)
#
# Runs in pre-commit (flux/apps/**) and in the Flux Diff workflow. Needs kustomize and yq (v4).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

for tool in kustomize yq; do
  command -v "${tool}" >/dev/null || { echo "check-app-security: ${tool} is required" >&2; exit 1; }
done

overlays=(
  flux/apps/backend/develop
  flux/apps/backend/staging
  flux/apps/backend/production
  flux/apps/frontend/overlays/develop
  flux/apps/frontend/overlays/staging
  flux/apps/frontend/overlays/production
)

failures=()

# The only accepted CHAOS_ENABLED per backend overlay (a case, not an associative array: macOS /bin/bash is 3.2).
expected_chaos_for() {
  case "$1" in
    flux/apps/backend/develop | flux/apps/backend/staging) echo true ;;
    flux/apps/backend/production) echo false ;;
    *) echo "" ;;
  esac
}

# backend_env OVERLAY_YAML NAME -> the value of env NAME in the backend container ("" when unset)
backend_env() {
  yq "select(.kind == \"Deployment\" and .metadata.name == \"backend\")
      | .spec.template.spec.containers[] | select(.name == \"backend\")
      | .env[] | select(.name == \"$2\") | .value" <<<"$1"
}

for overlay in "${overlays[@]}"; do
  if ! rendered="$(kustomize build "${overlay}" 2>&1)"; then
    failures+=("${overlay}: kustomize build failed: ${rendered}")
    continue
  fi

  deployments=0
  while IFS=$'\t' read -r name automount; do
    [[ -z "${name}" ]] && continue
    deployments=$((deployments + 1))
    if [[ "${automount}" != "false" ]]; then
      failures+=("${overlay}: Deployment ${name} must set automountServiceAccountToken: false (got: ${automount})")
    fi
  done < <(yq 'select(.kind == "Deployment") | [.metadata.name, (.spec.template.spec.automountServiceAccountToken | tostring)] | @tsv' <<<"${rendered}")
  if ((deployments == 0)); then
    failures+=("${overlay}: renders no Deployment - nothing was checked")
  fi

  while IFS= read -r target; do
    [[ -z "${target}" ]] && continue
    replicas="$(yq "select(.kind == \"Deployment\" and .metadata.name == \"${target}\") | .spec.replicas" <<<"${rendered}")"
    if [[ -n "${replicas}" && "${replicas}" != "null" ]]; then
      failures+=("${overlay}: Deployment ${target} has an HPA and must not set spec.replicas (got: ${replicas})")
    fi
  done < <(yq 'select(.kind == "HorizontalPodAutoscaler" and .spec.scaleTargetRef.kind == "Deployment") | .spec.scaleTargetRef.name' <<<"${rendered}")

  if [[ "${overlay}" == flux/apps/backend/* ]]; then
    pprof="$(backend_env "${rendered}" PPROF_ENABLED)"
    chaos="$(backend_env "${rendered}" CHAOS_ENABLED)"
    if [[ "${pprof}" != "false" ]]; then
      failures+=("${overlay}: backend PPROF_ENABLED must be \"false\" in Git (got: '${pprof}')")
    fi
    expected="$(expected_chaos_for "${overlay}")"
    if [[ -z "${expected}" ]]; then
      failures+=("${overlay}: no expected CHAOS_ENABLED value - add the overlay to expected_chaos_for")
    elif [[ "${chaos}" != "${expected}" ]]; then
      failures+=("${overlay}: backend CHAOS_ENABLED must be \"${expected}\" (got: '${chaos}')")
    fi
  fi
done

if ((${#failures[@]} > 0)); then
  echo "check-app-security: ${#failures[@]} problem(s):" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-app-security: OK (${#overlays[@]} overlays)"

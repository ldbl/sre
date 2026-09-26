#!/usr/bin/env bash
# Guardrail for the app manifests (security review 2026-09-27). Renders every backend and frontend
# overlay and fails when a rule is broken:
#   - every Deployment: automountServiceAccountToken: false (the apps never call the Kubernetes API)
#   - backend: PPROF_ENABLED is "false" everywhere (profiling is turned on by hand, never in Git)
#   - backend: CHAOS_ENABLED is set explicitly, and is "false" in production
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

  while IFS=$'\t' read -r name automount; do
    [[ -z "${name}" ]] && continue
    if [[ "${automount}" != "false" ]]; then
      failures+=("${overlay}: Deployment ${name} must set automountServiceAccountToken: false (got: ${automount})")
    fi
  done < <(yq 'select(.kind == "Deployment") | [.metadata.name, (.spec.template.spec.automountServiceAccountToken | tostring)] | @tsv' <<<"${rendered}")

  if [[ "${overlay}" == flux/apps/backend/* ]]; then
    pprof="$(backend_env "${rendered}" PPROF_ENABLED)"
    chaos="$(backend_env "${rendered}" CHAOS_ENABLED)"
    if [[ "${pprof}" != "false" ]]; then
      failures+=("${overlay}: backend PPROF_ENABLED must be \"false\" in Git (got: '${pprof}')")
    fi
    if [[ "${chaos}" != "true" && "${chaos}" != "false" ]]; then
      failures+=("${overlay}: backend CHAOS_ENABLED must be set to \"true\" or \"false\" (got: '${chaos}')")
    fi
    if [[ "${overlay}" == */production && "${chaos}" != "false" ]]; then
      failures+=("${overlay}: backend CHAOS_ENABLED must be \"false\" in production (got: '${chaos}')")
    fi
  fi
done

if ((${#failures[@]} > 0)); then
  echo "check-app-security: ${#failures[@]} problem(s):" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-app-security: OK (${#overlays[@]} overlays)"

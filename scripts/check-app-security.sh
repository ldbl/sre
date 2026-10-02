#!/usr/bin/env bash
# Guardrail for the app manifests (security review 2026-09-27). Renders every backend and frontend
# overlay and fails when a rule is broken:
#   - every Deployment: automountServiceAccountToken: false (the apps never call the Kubernetes API)
#   - every container (and init container): runAsNonRoot, readOnlyRootFilesystem, no privilege
#     escalation, capabilities drop ALL, seccomp RuntimeDefault - the container value wins over
#     the pod's, as in Kubernetes (admission only audits these, so this is where a regression stops)
#   - backend: PPROF_ENABLED is "false" everywhere (profiling is turned on by hand, never in Git)
#   - backend: CHAOS_ENABLED is exactly "true" in develop and staging (the chaos labs need it) and
#     "false" in production
#   - every overlay renders at least one Deployment (an empty render must not pass as OK)
#   - a Deployment targeted by an HPA sets no spec.replicas (the HPA owns the count; a value in Git
#     makes Flux reset what the HPA scaled on every reconcile)
#
# Runs in pre-commit (flux/apps/**) and in the Flux Diff workflow. Needs kubectl (for `kubectl kustomize`) and yq (v4).
# Usage: scripts/check-app-security.sh   (no arguments - it always checks all six overlays)
# Read-only: it renders the overlays locally and changes no file and no cluster. Every problem is
# collected first and printed together; exit 1 when there is at least one.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

for tool in kubectl yq; do
  command -v "${tool}" >/dev/null || { echo "check-app-security: ${tool} is required" >&2; exit 1; }
done

# The overlays Flux deploys: one per app and environment.
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
  # Render the overlay exactly as Flux would build it; every rule below reads this output.
  if ! rendered="$(kubectl kustomize "${overlay}" 2>&1)"; then
    failures+=("${overlay}: kustomize build failed: ${rendered}")
    continue
  fi

  # Rule: automountServiceAccountToken: false on every Deployment - and count the Deployments,
  # so an overlay that renders none fails instead of passing with nothing checked.
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

  # One line per container: deployment, container, runAsNonRoot (container, pod), readOnlyRootFilesystem,
  # allowPrivilegeEscalation, capabilities.drop, seccomp type (container, pod). Both levels are printed
  # and decided here: yq's // would treat an explicit false on the container as unset.
  # shellcheck disable=SC2016 # $pod and $d below are yq variables, not shell ones
  while IFS=$'\t' read -r dep ctr nonroot_c nonroot_p rofs ape drop seccomp_c seccomp_p; do
    [[ -z "${ctr}" ]] && continue
    where="${overlay}: Deployment ${dep} container ${ctr}"
    nonroot="${nonroot_c}"; [[ "${nonroot}" == "null" ]] && nonroot="${nonroot_p}"
    seccomp="${seccomp_c}"; [[ "${seccomp}" == "null" ]] && seccomp="${seccomp_p}"
    [[ "${nonroot}" == "true" ]] || failures+=("${where}: runAsNonRoot must be true (got: ${nonroot})")
    [[ "${rofs}" == "true" ]] || failures+=("${where}: readOnlyRootFilesystem must be true (got: ${rofs})")
    [[ "${ape}" == "false" ]] || failures+=("${where}: allowPrivilegeEscalation must be false (got: ${ape})")
    [[ ",${drop}," == *",ALL,"* ]] || failures+=("${where}: capabilities.drop must include ALL (got: '${drop}')")
    [[ "${seccomp}" == "RuntimeDefault" || "${seccomp}" == "Localhost" ]] ||
      failures+=("${where}: seccompProfile must be RuntimeDefault (got: ${seccomp})")
  done < <(yq 'select(.kind == "Deployment") | .spec.template.spec as $pod | .metadata.name as $d
      | ($pod.containers + ($pod.initContainers // []))[]
      | [$d, .name,
         (.securityContext.runAsNonRoot | tostring), ($pod.securityContext.runAsNonRoot | tostring),
         (.securityContext.readOnlyRootFilesystem | tostring),
         (.securityContext.allowPrivilegeEscalation | tostring),
         ((.securityContext.capabilities.drop // []) | join(",")),
         (.securityContext.seccompProfile.type | tostring), ($pod.securityContext.seccompProfile.type | tostring)]
      | @tsv' <<<"${rendered}")

  # Rule: for every Deployment an HPA scales, no spec.replicas in Git.
  while IFS= read -r target; do
    [[ -z "${target}" ]] && continue
    replicas="$(yq "select(.kind == \"Deployment\" and .metadata.name == \"${target}\") | .spec.replicas" <<<"${rendered}")"
    if [[ -n "${replicas}" && "${replicas}" != "null" ]]; then
      failures+=("${overlay}: Deployment ${target} has an HPA and must not set spec.replicas (got: ${replicas})")
    fi
  done < <(yq 'select(.kind == "HorizontalPodAutoscaler" and .spec.scaleTargetRef.kind == "Deployment") | .spec.scaleTargetRef.name' <<<"${rendered}")

  # Rules for the backend only: PPROF_ENABLED off, CHAOS_ENABLED as expected for the environment.
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

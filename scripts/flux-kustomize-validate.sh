#!/usr/bin/env bash
# flux-kustomize-validate.sh - pre-commit hook: do the Flux manifests you are about to commit build?
#
# For every kustomization directory under flux/ that a changed file belongs to (or all of them,
# when run without arguments):
#   1. build it with `kubectl kustomize` - a missing file, a broken patch or invalid YAML fails here;
#   2. if kubeconform is installed, validate the built objects against the Kubernetes and Flux CRD
#      schemas. Without kubeconform this step is skipped with a notice: the Flux Diff CI job runs
#      it on every pull request and fails on errors, so nothing reaches main unchecked.
# YAML syntax of single files is the yamllint hook's job.
#
# Needs only kubectl (already a lab tool). Optional: kubeconform, plus curl and tar for the schemas.
# Runs on macOS (bash 3.2) and Linux.
#
# Usage: scripts/flux-kustomize-validate.sh [changed files...]   (pre-commit passes the changed files)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUX_ROOT="${REPO_ROOT}/flux"

SCHEMA_URL="${FLUX_VALIDATE_SCHEMA_URL:-https://github.com/fluxcd/flux2/releases/download/v2.9.5/crd-schemas.tar.gz}"
SCHEMA_ROOT="${FLUX_VALIDATE_SCHEMA_ROOT:-/tmp/flux-crd-schemas}"
SCHEMA_VARIANT="${FLUX_VALIDATE_SCHEMA_VARIANT:-master-standalone-strict}"
SCHEMA_DIR="${SCHEMA_ROOT}/${SCHEMA_VARIANT}"
ALLOW_NO_FLUX_SCHEMAS="${FLUX_VALIDATE_ALLOW_NO_FLUX_SCHEMAS:-0}"
DISABLE_SCHEMA_DOWNLOAD="${FLUX_VALIDATE_DISABLE_SCHEMA_DOWNLOAD:-0}"

# LoadRestrictionsNone: some overlays reference files outside their own directory.
kustomize_flags=(--load-restrictor=LoadRestrictionsNone)
# Secrets under flux/secrets are SOPS-encrypted; their data does not match the Secret schema.
kubeconform_flags=(-skip=Secret)

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[flux-validate] required tool missing: kubectl" >&2
  exit 1
fi

# kubeconform is optional locally; when it is there, it needs tar (and curl to download schemas).
run_kubeconform=1
if ! command -v kubeconform >/dev/null 2>&1; then
  run_kubeconform=0
elif ! command -v tar >/dev/null 2>&1; then
  echo "[flux-validate] required tool missing: tar (for the Flux CRD schemas)" >&2
  exit 1
elif [[ "${DISABLE_SCHEMA_DOWNLOAD}" != "1" ]] && ! command -v curl >/dev/null 2>&1; then
  echo "[flux-validate] required tool missing: curl (to download the Flux CRD schemas)" >&2
  exit 1
fi

if [[ ! -d "${FLUX_ROOT}" ]]; then
  echo "[flux-validate] flux/ directory not found at ${FLUX_ROOT}" >&2
  exit 1
fi

# contains_kustomization <dir> - true when <dir> holds a kustomization.yaml (or .yml).
contains_kustomization() {
  local dir="$1"
  [[ -f "${dir}/kustomization.yaml" || -f "${dir}/kustomization.yml" ]]
}

# has_local_flux_schemas - true when the Flux CRD schemas were already downloaded (cached in /tmp).
has_local_flux_schemas() {
  [[ -d "${SCHEMA_DIR}" ]] && find "${SCHEMA_DIR}" -type f -name '*.json' -print -quit | grep -q .
}

# download_flux_schemas - fetch the Flux CRD JSON schemas of the pinned Flux release and unpack them.
download_flux_schemas() {
  local tmp_archive
  tmp_archive="$(mktemp "/tmp/flux-crd-schemas.XXXXXX.tar.gz")"

  echo "[flux-validate] downloading Flux CRD schemas from ${SCHEMA_URL}"
  if ! curl -fsSL "${SCHEMA_URL}" -o "${tmp_archive}"; then
    rm -f "${tmp_archive}"
    return 1
  fi

  rm -rf "${SCHEMA_DIR}"
  mkdir -p "${SCHEMA_DIR}"
  if ! tar zxf "${tmp_archive}" -C "${SCHEMA_DIR}"; then
    rm -f "${tmp_archive}"
    return 1
  fi

  rm -f "${tmp_archive}"
}

# ensure_flux_schemas - make the schemas available: cache, else download; with
# FLUX_VALIDATE_ALLOW_NO_FLUX_SCHEMAS=1 a failure only warns instead of stopping.
ensure_flux_schemas() {
  if has_local_flux_schemas; then
    echo "[flux-validate] using cached Flux schemas at ${SCHEMA_DIR}"
    return 0
  fi

  if [[ "${DISABLE_SCHEMA_DOWNLOAD}" == "1" ]]; then
    if [[ "${ALLOW_NO_FLUX_SCHEMAS}" == "1" ]]; then
      echo "[flux-validate] WARNING: Flux schema download disabled, validating without Flux CRD schemas."
      return 0
    fi
    echo "[flux-validate] Flux schemas missing and download disabled." >&2
    echo "[flux-validate] Set FLUX_VALIDATE_ALLOW_NO_FLUX_SCHEMAS=1 to allow fallback." >&2
    return 1
  fi

  if download_flux_schemas && has_local_flux_schemas; then
    echo "[flux-validate] Flux CRD schemas ready at ${SCHEMA_DIR}"
    return 0
  fi

  if [[ "${ALLOW_NO_FLUX_SCHEMAS}" == "1" ]]; then
    echo "[flux-validate] WARNING: failed to prepare Flux schemas, falling back without CRD schemas."
    return 0
  fi

  echo "[flux-validate] failed to prepare Flux schemas." >&2
  echo "[flux-validate] Set FLUX_VALIDATE_ALLOW_NO_FLUX_SCHEMAS=1 to allow fallback." >&2
  return 1
}

# Candidate directories are collected in a list and de-duplicated with sort -u.
# Plain lists, not associative arrays or readarray: macOS ships bash 3.2, which has neither.
# Every list is a temporary file, and every command that fills one is checked: a `< <(cmd)`
# process substitution would hide a failing find or sort, and the hook would quietly validate less.
DIR_LIST="$(mktemp)"
FOUND="$(mktemp)"
SORTED="$(mktemp)"
trap 'rm -f "${DIR_LIST}" "${FOUND}" "${SORTED}"' EXIT

# fail <message> - print the message and stop the hook.
fail() { echo "[flux-validate] $1" >&2; exit 1; }

# add_kustomize_parents <path> - list every directory from <path> up to the repository root that
# holds a kustomization: a change to one file can break each of them.
add_kustomize_parents() {
  local path="$1"
  local abs_path

  if [[ "${path}" = /* ]]; then
    abs_path="${path}"
  else
    abs_path="${REPO_ROOT}/${path}"
  fi

  local dir="${abs_path}"
  if [[ ! -d "${dir}" ]]; then
    dir="$(dirname "${dir}")"
  fi

  while [[ "${dir}" == "${REPO_ROOT}"* && "${dir}" != "/" ]]; do
    if contains_kustomization "${dir}"; then
      printf '%s\n' "${dir}" >> "${DIR_LIST}"
    fi
    if [[ "${dir}" == "${REPO_ROOT}" ]]; then
      break
    fi
    dir="$(dirname "${dir}")"
  done
}

if [[ $# -gt 0 ]]; then
  for changed in "$@"; do
    if [[ "${changed}" != flux/* ]]; then
      continue
    fi

    if [[ "${changed}" =~ \.ya?ml$ ]]; then
      add_kustomize_parents "${changed}"
    fi
  done
else
  find "${FLUX_ROOT}" -type f \( -name 'kustomization.yaml' -o -name 'kustomization.yml' \) -print0 > "${FOUND}" \
    || fail "find of the kustomizations under flux/ failed"
  while IFS= read -r -d '' kfile; do
    dirname "${kfile}" >> "${DIR_LIST}"
  done < "${FOUND}"
fi

if [[ ! -s "${DIR_LIST}" ]]; then
  echo "[flux-validate] No Flux manifests to validate."
  exit 0
fi

TARGET_DIRS=()
sort -u "${DIR_LIST}" > "${SORTED}" || fail "sort of the kustomization list failed"
while IFS= read -r d; do TARGET_DIRS+=("${d}"); done < "${SORTED}"

if [[ ${#TARGET_DIRS[@]} -eq 0 ]]; then
  echo "[flux-validate] No kustomizations affected."
  exit 0
fi

kubeconform_config=(-strict -ignore-missing-schemas -schema-location default)
if [[ ${run_kubeconform} -eq 1 ]]; then
  ensure_flux_schemas
  if has_local_flux_schemas; then
    kubeconform_config+=(-schema-location "${SCHEMA_ROOT}")
  elif [[ "${ALLOW_NO_FLUX_SCHEMAS}" == "1" ]]; then
    echo "[flux-validate] WARNING: skipping kubeconform (no local schemas available in fallback mode)."
    run_kubeconform=0
  fi
else
  echo "[flux-validate] kubeconform not installed: building only; the schema check runs in CI (Flux Diff)."
fi

failed=0
validated=0
skipped=0

for dir in ${TARGET_DIRS[@]+"${TARGET_DIRS[@]}"}; do
  rel_dir="${dir#${REPO_ROOT}/}"
  echo "[flux-validate] kustomize ${rel_dir}"

  set +e
  rendered="$(kubectl kustomize "${dir}" "${kustomize_flags[@]}" 2>&1)"
  build_status=$?
  set -e

  if [[ ${build_status} -ne 0 ]]; then
    if grep -Eqi "must build at least one resource|kustomization\\.ya?ml is empty" <<<"${rendered}"; then
      echo "[flux-validate] skipped ${rel_dir} (empty kustomization)"
      skipped=$((skipped + 1))
      continue
    fi

    echo "[flux-validate] FAILED ${rel_dir}" >&2
    echo "${rendered}" >&2
    failed=1
    continue
  fi

  if [[ ${run_kubeconform} -eq 1 ]]; then
    if ! printf '%s\n' "${rendered}" | kubeconform "${kubeconform_flags[@]}" "${kubeconform_config[@]}"; then
      echo "[flux-validate] FAILED schema validation for ${rel_dir}" >&2
      failed=1
      continue
    fi
  fi

  validated=$((validated + 1))
done

echo "[flux-validate] summary: validated=${validated} skipped=${skipped}"
exit "${failed}"

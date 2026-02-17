#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${1:-${ROOT_DIR}/docs/course}"
DST_DIR="${2:-${ROOT_DIR}/site/content/course}"

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "[sync-course-to-hugo] source directory not found: ${SRC_DIR}" >&2
  exit 1
fi

rm -rf "${DST_DIR}"
mkdir -p "${DST_DIR}"

extract_title() {
  local file="$1"
  local title
  title="$(awk '/^# /{sub(/^# /, ""); print; exit}' "${file}" || true)"
  if [[ -n "${title}" ]]; then
    printf '%s' "${title}"
    return 0
  fi
  basename "${file}" .md | tr '_' ' ' | tr '-' ' '
}

chapter_weight_from_path() {
  local rel_path="$1"
  local chapter
  chapter="$(printf '%s' "${rel_path}" | sed -nE 's|^chapter-([0-9]{2}).*|\1|p')"
  if [[ -n "${chapter}" ]]; then
    printf '%d' "${chapter#0}"
    return 0
  fi
  printf '999'
}

while IFS= read -r src_file; do
  rel_path="${src_file#${SRC_DIR}/}"

  case "${rel_path}" in
    _lesson-template.md)
      continue
      ;;
    README.md)
      dst_file="${DST_DIR}/_index.md"
      ;;
    */README.md)
      dst_file="${DST_DIR}/${rel_path%README.md}_index.md"
      ;;
    *)
      dst_file="${DST_DIR}/${rel_path}"
      ;;
  esac

  mkdir -p "$(dirname "${dst_file}")"

  if grep -qE '^---$' "${src_file}"; then
    cp "${src_file}" "${dst_file}"
    continue
  fi

  title="$(extract_title "${src_file}")"
  weight="$(chapter_weight_from_path "${rel_path}")"

  {
    echo "---"
    echo "title: \"${title}\""
    if [[ "${rel_path}" == chapter-*"/README.md" ]]; then
      echo "weight: ${weight}"
    fi
    echo "---"
    echo
    cat "${src_file}"
  } > "${dst_file}"
done < <(find "${SRC_DIR}" -type f -name '*.md' | sort)

echo "[sync-course-to-hugo] synced ${SRC_DIR} -> ${DST_DIR}"

#!/usr/bin/env bash
# configure-repo.sh - point a copy of the platform repository at your own GitHub owner and repo.
#
# The repository has the original owner's names written into docs/, flux/ and infra/terraform/:
# the Git URL Flux syncs from (https and ssh forms) and the GHCR image names of the backend and
# frontend. This script finds every file that contains them and rewrites them in place, so Flux
# follows your repository and pulls your images. Run it once, by hand, after copying the
# repository (docs/hetzner.md), then review the diff and commit it.
#
# Usage: scripts/configure-repo.sh --github-owner <owner> [--github-repo <repo>]   (repo defaults to sre)
# Needs rg (ripgrep) to find the files and perl to rewrite them.
# Changes: files under docs/, flux/ and infra/terraform/ in your working copy; nothing in a cluster.
set -euo pipefail

# usage - print how to call the script.
usage() {
  cat <<'EOF'
usage: scripts/configure-repo.sh --github-owner <owner> [--github-repo <repo>]

Updates hardcoded defaults in docs/ and flux/ to match your GitHub org/user and repo name.

Examples:
  scripts/configure-repo.sh --github-owner stan --github-repo sre
EOF
}

GITHUB_OWNER=""
GITHUB_REPO="sre"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --github-owner)
      GITHUB_OWNER="${2:-}"
      shift 2
      ;;
    --github-repo)
      GITHUB_REPO="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${GITHUB_OWNER}" ]]; then
  echo "--github-owner is required" >&2
  usage >&2
  exit 2
fi

# The names the files contain today - the ones to replace.
OLD_OWNER="ldbl"
OLD_REPO="sre"

NEW_HTTPS_REPO_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}.git"
NEW_SSH_REPO_URL="ssh://git@github.com/${GITHUB_OWNER}/${GITHUB_REPO}.git"

# Every file that mentions one of the old names (rg -l prints file names only). A plain while-read
# loop instead of mapfile, so the script also runs with macOS's bash 3.2.
FILES=()
while IFS= read -r f; do FILES+=("$f"); done < <(
  rg -l --fixed-strings \
    "github.com/${OLD_OWNER}/${OLD_REPO}.git" \
    "ghcr.io/${OLD_OWNER}/backend" \
    "ghcr.io/${OLD_OWNER}/frontend" \
    docs flux infra/terraform 2>/dev/null || true
)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "[configure-repo] nothing to update"
  exit 0
fi

echo "[configure-repo] updating ${#FILES[@]} file(s)"

for f in "${FILES[@]}"; do
  # repo URLs
  perl -pi -e "s#https://github\\.com/${OLD_OWNER}/${OLD_REPO}\\.git#${NEW_HTTPS_REPO_URL}#g" "$f"
  perl -pi -e "s#ssh://git@github\\.com/${OLD_OWNER}/${OLD_REPO}\\.git#${NEW_SSH_REPO_URL}#g" "$f"

  # GHCR images
  perl -pi -e "s#ghcr\\.io/${OLD_OWNER}/backend#ghcr.io/${GITHUB_OWNER}/backend#g" "$f"
  perl -pi -e "s#ghcr\\.io/${OLD_OWNER}/frontend#ghcr.io/${GITHUB_OWNER}/frontend#g" "$f"
done

echo "[configure-repo] done"


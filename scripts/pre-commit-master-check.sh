#!/bin/bash
# pre-commit-master-check.sh - pre-commit hook master-branch-check: no commit, push or merge commit
# directly on a protected branch (main, master). Every change goes through a feature branch and a
# pull request, where review and CI see it.
#
# Runs at the pre-commit, pre-push and pre-merge-commit stages (.pre-commit-config.yaml), which
# passes --protected=master --protected=main.
# Usage: scripts/pre-commit-master-check.sh [--protected=<branch or glob>]...
#   Without --protected it protects master and main. Needs git; changes nothing.
set -e

DEFAULT_PROTECTED=("master" "main")
PROTECTED_PATTERNS=()

# Collect --protected values; any other argument (pre-commit may pass file names) is ignored.
while [[ $# -gt 0 ]]; do
    case $1 in
        --protected=*) PROTECTED_PATTERNS+=("${1#*=}"); shift ;;
        --protected)
            if [[ $# -ge 2 ]]; then
                PROTECTED_PATTERNS+=("$2"); shift 2
            else
                echo "Error: --protected requires a value" >&2; exit 1
            fi
            ;;
        *) shift ;;
    esac
done

if [ ${#PROTECTED_PATTERNS[@]} -eq 0 ]; then
    PROTECTED_PATTERNS=("${DEFAULT_PROTECTED[@]}")
fi

# A detached HEAD has no branch name to check, so the hook refuses instead of guessing.
current_branch=$(git branch --show-current || true)
if [[ -z "$current_branch" ]]; then
    echo "Cannot determine current branch (detached HEAD). Aborting." >&2
    exit 1
fi

# The pattern is unquoted on purpose, so a value like "release/*" works as a glob.
for pattern in "${PROTECTED_PATTERNS[@]}"; do
    # shellcheck disable=SC2053
    if [[ -n "$pattern" && "$current_branch" == $pattern ]]; then
        echo ""
        echo "COMMIT BLOCKED: Cannot commit directly to '$current_branch'"
        echo "Create a feature branch first: git checkout -b feature/your-task-name"
        echo ""
        exit 1
    fi
done

exit 0

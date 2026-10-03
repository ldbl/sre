#!/bin/bash
# prevent-amend-after-push.sh - pre-commit hook prevent-amend-after-push: refuse `git commit --amend`
# when the commit being amended is already on a remote branch. Amending a pushed commit rewrites
# shared history and forces a force-push; a new commit on top is the safe way to fix it.
#
# Runs at the prepare-commit-msg stage (.pre-commit-config.yaml). Git calls that hook with
# <message file> <source> <sha>; through pre-commit the source and sha arrive as environment
# variables instead (see below). For an amend the source is "commit" and the sha is the commit
# being amended. Note: `git commit --no-verify` does not skip this stage. Tests:
# tests/prevent-amend-after-push.test.sh
# Usage: called by git through pre-commit, not by hand. Needs git; changes nothing.
set -Eeuo pipefail

# Skip if not in git repo or no remotes or no commits
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
git remote 2>/dev/null | grep -q . || exit 0
git rev-parse HEAD >/dev/null 2>&1 || exit 0

# Only block amend operations: the message source is "commit" and the object is the commit being
# amended. Git passes them as $2 and $3; pre-commit does not - it puts them into
# PRE_COMMIT_COMMIT_MSG_SOURCE and PRE_COMMIT_COMMIT_OBJECT_NAME. Reading only $2 made the hook pass
# every amend when pre-commit ran it - the way make install-hooks installs it.
source="${PRE_COMMIT_COMMIT_MSG_SOURCE:-${2:-}}"
[[ "${source}" == "commit" ]] || exit 0

target_sha="${PRE_COMMIT_COMMIT_OBJECT_NAME:-${3:-HEAD}}"

# Any remote-tracking branch that contains the commit means it was pushed. Symbolic refs
# ("origin/HEAD -> origin/main") are left out so the same branch is not counted twice.
# -e: a pattern that starts with "-" would otherwise be read as an option, grep would fail, and the
# hook would never block.
if git branch -r --contains "$target_sha" 2>/dev/null | grep -vF -e '->' | grep -v 'origin/HEAD' | grep -q .; then
  echo ""
  echo "BLOCKED: Cannot amend commits that have been pushed!"
  echo "Remote branches containing this commit:"
  git branch -r --contains "$target_sha" 2>/dev/null | sed 's/^[[:space:]]*//' | grep -vF -e '->' | grep -v 'origin/HEAD'
  echo ""
  echo "Create a new commit instead: git commit -m 'fix: ...'"
  echo ""
  exit 1
fi

exit 0

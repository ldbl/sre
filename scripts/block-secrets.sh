#!/bin/bash
# block-secrets.sh - pre-commit hook no-secrets: refuse to commit files that hold secrets.
#
# The hook's `files` pattern in .pre-commit-config.yaml selects kubeconfigs, private keys (.key,
# .pem, age .agekey), credentials files, .env files, and Terraform state and saved plans; any staged file it
# passes here is refused.
# The script itself checks nothing: pre-commit only calls it when at least one staged file matches,
# so reaching it means "blocked". It lists the files and exits 1, which stops the commit - also for
# a file added with `git add -f` past .gitignore. The Secrets guard CI job runs the same hook.
#
# Usage: called by pre-commit with the matching files as arguments. Needs nothing; changes nothing.
echo "BLOCKED: sensitive file(s) staged for commit:" >&2
for f in "$@"; do echo "  $f" >&2; done
echo "Unstage them (git restore --staged <file>); keep credentials, Terraform state and plans out of Git - see flux/secrets/README.md for secrets Flux needs." >&2
exit 1

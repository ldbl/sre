#!/bin/bash
# pre-commit hook no-secrets: the hook's `files` pattern selects kubeconfigs, private keys (.key,
# .pem, age .agekey), credentials files, .env files, and Terraform state and saved plans; any staged file it
# passes here is refused.
echo "BLOCKED: sensitive file(s) staged for commit:" >&2
for f in "$@"; do echo "  $f" >&2; done
echo "Unstage them (git restore --staged <file>); keep credentials, Terraform state and plans out of Git - see flux/secrets/README.md for secrets Flux needs." >&2
exit 1

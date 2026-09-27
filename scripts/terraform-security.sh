#!/bin/bash
# Checkov security scan of both Terraform modules (pre-commit hook terraform-security).
# Checkov is a required tool (scripts/check-tools.sh): without it the hook fails instead of
# skipping, so "every commit that touches .tf is scanned" stays true.
set -e
if ! command -v checkov &>/dev/null; then
    echo "ERROR: checkov is not installed - the Terraform security scan cannot run" >&2
    echo "Install: brew install checkov (macOS) or pip install checkov; see scripts/check-tools.sh" >&2
    exit 1
fi
checkov -d infra/terraform/kind_cluster -d infra/terraform/hcloud_cluster --framework terraform --quiet --compact

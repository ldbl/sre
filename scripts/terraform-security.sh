#!/bin/bash
# terraform-security.sh - Checkov security scan of the Terraform modules (pre-commit hook
# terraform-security, runs when a .tf or .tfvars file is staged).
#
# Checkov reads the code, not the cluster, and reports settings known to be risky (a secret in
# plain text, a network rule open to the world). It scans the kind module, the Hetzner module and
# the state lab.
# Checkov is a required tool (scripts/check-tools.sh): without it the hook fails instead of
# skipping, so "every commit that touches .tf is scanned" stays true.
#
# Usage: scripts/terraform-security.sh   (from the repository root). Needs checkov; changes nothing.
set -e
if ! command -v checkov &>/dev/null; then
    echo "ERROR: checkov is not installed - the Terraform security scan cannot run" >&2
    echo "Install: brew install checkov (macOS) or pip install checkov; see scripts/check-tools.sh" >&2
    exit 1
fi
checkov -d infra/terraform/kind_cluster -d infra/terraform/hcloud_cluster -d infra/terraform/state-lab --framework terraform --quiet --compact

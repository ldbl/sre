#!/bin/bash
set -e
if command -v checkov &>/dev/null; then
    checkov -d infra/terraform/hcloud_cluster --framework terraform --quiet --compact --soft-fail
else
    echo "checkov not installed, skipping security scan"
fi

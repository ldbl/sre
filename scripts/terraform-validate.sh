#!/bin/bash
set -e
# Validate every Terraform module the course uses: the local kind cluster
# (core track), the Hetzner cluster (cloud track) and the state lab.
#
# Each module is initialised in its own throw-away TF_DATA_DIR with
# -backend=false: validate needs the providers and modules, never the state.
# The module's real .terraform/ is not touched, so a directory that was once
# initialised against a remote backend (R2) does not make validate read that
# backend - or fail on whatever cloud credentials happen to be in the shell.
for dir in infra/terraform/kind_cluster infra/terraform/hcloud_cluster infra/terraform/state-lab; do
    echo "terraform validate: ${dir}"
    data_dir="$(mktemp -d)"
    TF_DATA_DIR="${data_dir}" terraform -chdir="${dir}" init -input=false -backend=false >/dev/null
    TF_DATA_DIR="${data_dir}" terraform -chdir="${dir}" validate
    rm -rf "${data_dir}"
done

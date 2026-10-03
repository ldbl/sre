#!/bin/bash
set -e
# terraform-validate.sh - pre-commit hook terraform-validate (runs when a .tf or .tfvars file is
# staged); `make validate` and the Pre-commit CI job run it too.
#
# Validate every Terraform module the course uses: the local kind cluster
# (core track), the Hetzner cluster (cloud track) and the state lab.
# Usage: scripts/terraform-validate.sh   (from the repository root). Needs terraform; changes no
# state and no cluster.
#
# Each module is initialised in its own throw-away TF_DATA_DIR with
# -backend=false: validate needs the providers and modules, never the state.
# The module's real .terraform/ is not touched, so a directory that was once
# initialised against a remote backend (R2) does not make validate read that
# backend - or fail on whatever cloud credentials happen to be in the shell.
# The trap removes the current module's data dir also when init or validate
# fails (set -e exits before the rm below); each dir holds the providers.
#
# Providers are downloaded once into a shared plugin cache (TF_PLUGIN_CACHE_DIR, default
# ~/.terraform.d/plugin-cache) and linked from there. Without it every run downloaded every provider
# of all three modules again - half a minute per commit, and one flaky download from GitHub failed
# the hook (found in the Chapter 05 lab, 2026-10-04).
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-${HOME}/.terraform.d/plugin-cache}"
mkdir -p "${TF_PLUGIN_CACHE_DIR}"

data_dir=""
trap 'if [ -n "${data_dir}" ]; then rm -rf "${data_dir}"; fi' EXIT
for dir in infra/terraform/kind_cluster infra/terraform/hcloud_cluster infra/terraform/state-lab; do
  echo "terraform validate: ${dir}"
  data_dir="$(mktemp -d)"
  TF_DATA_DIR="${data_dir}" terraform -chdir="${dir}" init -input=false -backend=false >/dev/null
  TF_DATA_DIR="${data_dir}" terraform -chdir="${dir}" validate
  rm -rf "${data_dir}"
  data_dir=""
done

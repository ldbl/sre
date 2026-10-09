#!/usr/bin/env bash
# Unit test for the platform alerts (flux/infrastructure/observability/kube-prometheus-stack/
# monitoring/platform-alerts.yaml): promtool evaluates the rules against made-up series in
# tests/platform-alerts/tests.yaml and fails when an alert fires where it should not, or stays
# silent where it should fire - the restart loop that exits 0, the component that keeps a core busy.
#
# Runs in pre-commit and CI; no cluster, no network. Needs promtool (make check-tools) and yq (v4).
# The PrometheusRule is a Kubernetes object; promtool wants a plain rules file, so its spec is
# extracted into a temporary directory first.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rule="${repo_root}/flux/infrastructure/observability/kube-prometheus-stack/monitoring/platform-alerts.yaml"
tests="${repo_root}/tests/platform-alerts/tests.yaml"

for tool in promtool yq; do
  command -v "${tool}" >/dev/null || { echo "platform-alerts: ${tool} is required (make check-tools)" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

yq '.spec' "${rule}" > "${work}/rules.yaml"
cp "${tests}" "${work}/tests.yaml"
promtool check rules "${work}/rules.yaml"
promtool test rules "${work}/tests.yaml"

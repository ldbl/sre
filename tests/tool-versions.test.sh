#!/usr/bin/env bash
# Do the tools the tests run match what the cluster runs? The policy tests use the Kyverno CLI and
# the alert tests use promtool - both pinned in .github/workflows/pre-commit.yml. The cluster gets
# Kyverno and Prometheus from Helm charts pinned in flux/. A chart bump without the matching tool
# bump - or the other way round - and the tests verify against an engine the cluster does not run:
# in 2026-10 the policy tests ran Kyverno 1.19 while the cluster ran 1.17 (chart 3.7.1), and a
# passing test said nothing about admission (Chapter 20).
#
# For each pair it asks Helm what the pinned chart installs (`helm show`) and compares:
#   Kyverno CLI  KYVERNO_VERSION     == appVersion of the kyverno chart in flux/infrastructure/policy/kyverno
#   promtool     PROMETHEUS_VERSION  == the Prometheus image tag of the kube-prometheus-stack chart
#
# Runs in pre-commit and CI when one of those files changes. Needs helm, yq and the network (the
# charts' repositories); read-only.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="${root}/.github/workflows/pre-commit.yml"
for tool in helm yq; do
  command -v "${tool}" >/dev/null || { echo "tool-versions: ${tool} is required (make check-tools)" >&2; exit 1; }
done

# ci_pin NAME - the value of an env variable pinned on a step of the pre-commit workflow.
ci_pin() { yq ".jobs[].steps[].env.${1} // \"\" | select(. != \"\")" "${workflow}" | head -1; }

# chart_of RELEASE_FILE - "<repository url> <chart> <version>" of a HelmRelease, the URL taken from
# the HelmRepository its sourceRef names.
chart_of() {
  local release="$1" chart version source url
  chart="$(yq '.spec.chart.spec.chart' "${release}")"
  version="$(yq '.spec.chart.spec.version' "${release}")"
  source="$(yq '.spec.chart.spec.sourceRef.name' "${release}")"
  url="$(grep -rl 'kind: HelmRepository' "${root}/flux" | xargs yq "select(.kind == \"HelmRepository\" and .metadata.name == \"${source}\") | .spec.url" | head -1)"
  [[ -n "${url}" ]] || { echo "tool-versions: no HelmRepository named ${source} under flux/" >&2; exit 1; }
  echo "${url} ${chart} ${version}"
}

failed=0
# compare WHAT TOOL_VERSION CLUSTER_VERSION - equal once a leading v is dropped.
compare() {
  if [[ "${2#v}" == "${3#v}" ]]; then
    echo "ok   $1: tests ${2#v} = cluster ${3#v}"
  else
    echo "FAIL $1: the tests run ${2#v}, the cluster runs ${3#v} - bump them together" >&2
    failed=1
  fi
}

read -r url chart version < <(chart_of "${root}/flux/infrastructure/policy/kyverno/release.yaml")
compare "Kyverno (CLI vs chart ${chart} ${version})" "$(ci_pin KYVERNO_VERSION)" \
  "$(helm show chart "${chart}" --repo "${url}" --version "${version}" | yq '.appVersion')"

read -r url chart version < <(chart_of "${root}/flux/infrastructure/observability/kube-prometheus-stack/base/release.yaml")
compare "Prometheus (promtool vs chart ${chart} ${version})" "$(ci_pin PROMETHEUS_VERSION)" \
  "$(helm show values "${chart}" --repo "${url}" --version "${version}" | yq '.prometheus.prometheusSpec.image.tag')"

exit "${failed}"

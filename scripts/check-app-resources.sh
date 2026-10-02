#!/usr/bin/env bash
# Guardrail for app resources (2026-09-27: production backend had lower limits than develop, and
# staging the lowest of all). Renders the overlays and fails when:
#   - staging and production differ for an app (staging is the pre-production copy of production)
#   - production gets less than develop for any request or limit
#   - a namespace quota cannot hold the worst case: every app at HPA maxReplicas + its rolling-update
#     surge, plus the Postgres instances - checked for requests, limits and the pod count
# A pod's resources are what Kubernetes charges against the quota: for each request/limit the larger
# of (the sum over regular containers) and (the largest single init container).
#
# A broken input (a failed kustomize build, a missing or duplicate HPA, a missing request/limit)
# stops the run at once with a message; rule violations are collected and reported together.
#
# Runs in pre-commit and in the Flux Diff workflow. Needs kubectl (for `kubectl kustomize`) and yq (v4).
# Usage: scripts/check-app-resources.sh   (no arguments - it renders every app, CNPG and quota overlay)
# Read-only: it changes no file and no cluster; it prints the worst case per namespace and exits 1
# on any problem.
set -euo pipefail
# set -e also inside $(...) (bash >= 4.4); macOS /bin/bash 3.2 lacks it, the explicit checks still catch errors
shopt -s inherit_errexit 2>/dev/null || true

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

for tool in kubectl yq; do
  command -v "${tool}" >/dev/null || { echo "check-app-resources: ${tool} is required" >&2; exit 1; }
done

envs=(develop staging production)
apps=(backend frontend)
failures=()

# die MESSAGE - stop at once: used for broken input, not for rule violations.
die() { echo "check-app-resources: $*" >&2; exit 1; }

# app_overlay APP ENV -> the overlay directory (the frontend keeps its overlays one level deeper).
app_overlay() { # app env
  if [[ "$1" == frontend ]]; then echo "flux/apps/frontend/overlays/$2"; else echo "flux/apps/$1/$2"; fi
}

# yq over a multi-document render prints an empty line and "---" for every document that does not
# match; keep only the real results.
yqs() { yq -N "$1" | sed -e '/^$/d' -e '/^---$/d'; }

# kustomize build, failing loudly. Callers assign with a plain `var="$(render ...)"` so that
# `set -e` stops the script when the build fails (a `local` or a here-string would hide it).
render() { kubectl kustomize "$1" || die "kustomize build $1 failed"; }

# CPU quantity -> millicores ("250m" -> 250, "1" -> 1000, "0.5" -> 500); anything else stops the run
to_milli() {
  local q="$1"
  if [[ "${q}" =~ ^[0-9]+m$ ]]; then
    echo "${q%m}"
  elif [[ "${q}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    awk -v v="${q}" 'BEGIN { printf "%d", v * 1000 }'
  else
    die "unsupported or missing CPU quantity '${q}' ($2)"
  fi
}

# Memory quantity -> MiB ("256Mi" -> 256, "3Gi" -> 3072, "512Ki" -> 1, rounded up)
to_mib() {
  local q="$1"
  case "${q}" in
    *Gi) awk -v v="${q%Gi}" 'BEGIN { printf "%d", v * 1024 }' ;;
    *Mi) echo "${q%Mi}" ;;
    *Ki) awk -v v="${q%Ki}" 'BEGIN { printf "%d", (v + 1023) / 1024 }' ;;
    *) die "unsupported or missing memory quantity '${q}' ($2)" ;;
  esac
}

# pod_resources RENDER WHERE -> "reqCpu reqMem limCpu limMem" (millicores / MiB), summed over every
# regular container of the single Deployment in RENDER.
pod_resources() {
  local rendered="$1" where="$2" deployments lines rc rm lc lm
  local sum_rc=0 sum_rm=0 sum_lc=0 sum_lm=0 v
  deployments="$(yqs 'select(.kind == "Deployment") | .metadata.name' <<<"${rendered}" | wc -l | tr -d ' ')"
  [[ "${deployments}" == 1 ]] || die "${where}: expected exactly 1 Deployment, found ${deployments}"
  lines="$(yqs 'select(.kind == "Deployment") | .spec.template.spec.containers[] | .resources | [.requests.cpu, .requests.memory, .limits.cpu, .limits.memory] | @tsv' <<<"${rendered}")"
  [[ -n "${lines}" ]] || die "${where}: the Deployment has no containers"
  while IFS=$'\t' read -r rc rm lc lm; do
    v="$(to_milli "${rc}" "${where} requests.cpu")"; sum_rc=$((sum_rc + v))
    v="$(to_mib "${rm}" "${where} requests.memory")"; sum_rm=$((sum_rm + v))
    v="$(to_milli "${lc}" "${where} limits.cpu")"; sum_lc=$((sum_lc + v))
    v="$(to_mib "${lm}" "${where} limits.memory")"; sum_lm=$((sum_lm + v))
  done <<<"${lines}"
  # Init containers run one at a time before the others: the pod needs the larger of the two.
  local init_lines max_rc=0 max_rm=0 max_lc=0 max_lm=0
  init_lines="$(yqs 'select(.kind == "Deployment") | .spec.template.spec.initContainers[]? | .resources | [.requests.cpu, .requests.memory, .limits.cpu, .limits.memory] | @tsv' <<<"${rendered}")"
  if [[ -n "${init_lines}" ]]; then
    while IFS=$'\t' read -r rc rm lc lm; do
      v="$(to_milli "${rc}" "${where} init requests.cpu")"; ((v > max_rc)) && max_rc=${v}
      v="$(to_mib "${rm}" "${where} init requests.memory")"; ((v > max_rm)) && max_rm=${v}
      v="$(to_milli "${lc}" "${where} init limits.cpu")"; ((v > max_lc)) && max_lc=${v}
      v="$(to_mib "${lm}" "${where} init limits.memory")"; ((v > max_lm)) && max_lm=${v}
    done <<<"${init_lines}"
  fi
  ((max_rc > sum_rc)) && sum_rc=${max_rc}
  ((max_rm > sum_rm)) && sum_rm=${max_rm}
  ((max_lc > sum_lc)) && sum_lc=${max_lc}
  ((max_lm > sum_lm)) && sum_lm=${max_lm}
  echo "${sum_rc} ${sum_rm} ${sum_lc} ${sum_lm}"
}

# worst_case_pods RENDER WHERE -> HPA maxReplicas + rolling-update surge
worst_case_pods() {
  local rendered="$1" where="$2" hpas max surge
  hpas="$(yqs 'select(.kind == "HorizontalPodAutoscaler") | .metadata.name' <<<"${rendered}" | wc -l | tr -d ' ')"
  [[ "${hpas}" == 1 ]] || die "${where}: expected exactly 1 HorizontalPodAutoscaler, found ${hpas}"
  max="$(yqs 'select(.kind == "HorizontalPodAutoscaler") | .spec.maxReplicas' <<<"${rendered}")"
  [[ "${max}" =~ ^[1-9][0-9]*$ ]] || die "${where}: HPA maxReplicas '${max}' is not a positive integer"
  surge="$(yqs 'select(.kind == "Deployment") | .spec.strategy.rollingUpdate.maxSurge // "25%"' <<<"${rendered}")"
  if [[ "${surge}" =~ ^([0-9]+)%$ ]]; then
    surge="$(awk -v m="${max}" -v p="${BASH_REMATCH[1]}" 'BEGIN { s = m * p / 100; printf "%d", (s == int(s)) ? s : int(s) + 1 }')"
  fi
  [[ "${surge}" =~ ^[0-9]+$ ]] || die "${where}: maxSurge '${surge}' is neither an integer nor a percentage"
  echo $((max + surge))
}

# Names of the four numbers pod_resources returns, in the same order - for the messages.
labels=("requests.cpu (m)" "requests.memory (Mi)" "limits.cpu (m)" "limits.memory (Mi)")

# Render every app overlay once; the checks below reuse it.
# declare_render NAME VALUE / get_render APP ENV - store and read a render in a variable named
# render_<app>_<env> (bash 3.2 has no associative arrays).
declare_render() { printf -v "$1" '%s' "$2"; }
for app in "${apps[@]}"; do
  for env in "${envs[@]}"; do
    rendered="$(render "$(app_overlay "${app}" "${env}")")"
    declare_render "render_${app}_${env}" "${rendered}"
  done
done
get_render() { local name="render_$1_$2"; printf '%s' "${!name}"; }

# 1 + 2: parity and production >= develop
for app in "${apps[@]}"; do
  s="$(pod_resources "$(get_render "${app}" develop)" "${app}/develop")"; read -r -a dev <<<"${s}"
  s="$(pod_resources "$(get_render "${app}" staging)" "${app}/staging")"; read -r -a stg <<<"${s}"
  s="$(pod_resources "$(get_render "${app}" production)" "${app}/production")"; read -r -a prd <<<"${s}"
  for i in 0 1 2 3; do
    if [[ "${stg[$i]}" != "${prd[$i]}" ]]; then
      failures+=("${app}: ${labels[$i]} staging=${stg[$i]} but production=${prd[$i]} - staging must match production")
    fi
    if ((prd[i] < dev[i])); then
      failures+=("${app}: ${labels[$i]} production=${prd[$i]} is below develop=${dev[$i]}")
    fi
  done
done

# 3: quota budget per namespace - add up the worst case of every app and Postgres, then compare
# it with the namespace's ResourceQuota.
for env in "${envs[@]}"; do
  need=(0 0 0 0)
  need_pods=0
  breakdown=()

  for app in "${apps[@]}"; do
    rendered="$(get_render "${app}" "${env}")"
    pods="$(worst_case_pods "${rendered}" "${app}/${env}")"
    s="$(pod_resources "${rendered}" "${app}/${env}")"; read -r -a per_pod <<<"${s}"
    for i in 0 1 2 3; do need[i]=$((need[i] + pods * per_pod[i])); done
    need_pods=$((need_pods + pods))
    breakdown+=("${app} ${pods}x")
  done

  # Postgres: every CNPG instance is one more pod with the Cluster's resources.
  cnpg="$(render "flux/infrastructure/data/cnpg-clusters/${env}")"
  instances="$(yqs 'select(.kind == "Cluster") | .spec.instances' <<<"${cnpg}")"
  [[ "${instances}" =~ ^[1-9][0-9]*$ ]] || die "cnpg ${env}: expected one Cluster with a positive spec.instances, got '${instances}'"
  IFS=$'\t' read -r prc prm plc plm <<<"$(yqs 'select(.kind == "Cluster") | .spec.resources | [.requests.cpu, .requests.memory, .limits.cpu, .limits.memory] | @tsv' <<<"${cnpg}")"
  v="$(to_milli "${prc}" "cnpg ${env} requests.cpu")"; need[0]=$((need[0] + instances * v))
  v="$(to_mib "${prm}" "cnpg ${env} requests.memory")"; need[1]=$((need[1] + instances * v))
  v="$(to_milli "${plc}" "cnpg ${env} limits.cpu")"; need[2]=$((need[2] + instances * v))
  v="$(to_mib "${plm}" "cnpg ${env} limits.memory")"; need[3]=$((need[3] + instances * v))
  need_pods=$((need_pods + instances))
  breakdown+=("postgres ${instances}x")

  # What the namespace allows: the ResourceQuota's hard limits.
  quota="$(render "flux/infrastructure/resource-management/${env}")"
  IFS=$'\t' read -r qrc qrm qlc qlm <<<"$(yqs 'select(.kind == "ResourceQuota") | .spec.hard | [."requests.cpu", ."requests.memory", ."limits.cpu", ."limits.memory"] | @tsv' <<<"${quota}")"
  have=()
  v="$(to_milli "${qrc}" "quota ${env} requests.cpu")"; have+=("${v}")
  v="$(to_mib "${qrm}" "quota ${env} requests.memory")"; have+=("${v}")
  v="$(to_milli "${qlc}" "quota ${env} limits.cpu")"; have+=("${v}")
  v="$(to_mib "${qlm}" "quota ${env} limits.memory")"; have+=("${v}")
  for i in 0 1 2 3; do
    if ((need[i] > have[i])); then
      failures+=("${env}: worst case (${breakdown[*]}) needs ${labels[$i]}=${need[$i]} but the quota allows ${have[$i]}")
    fi
  done
  # Pod count: only the apps and Postgres are counted here; other pods in the namespace (CronJobs,
  # lab pods) need the rest of the quota, so this is a floor, not the whole budget.
  quota_pods="$(yqs 'select(.kind == "ResourceQuota") | .spec.hard.pods // ""' <<<"${quota}")"
  if [[ -n "${quota_pods}" ]]; then
    [[ "${quota_pods}" =~ ^[0-9]+$ ]] || die "quota ${env}: pods '${quota_pods}' is not an integer"
    if ((need_pods > quota_pods)); then
      failures+=("${env}: worst case (${breakdown[*]}) needs ${need_pods} pods but the quota allows ${quota_pods}")
    fi
  fi
  echo "  ${env}: worst case (${breakdown[*]}) requests ${need[0]}m/${need[1]}Mi of ${have[0]}m/${have[1]}Mi, limits ${need[2]}m/${need[3]}Mi of ${have[2]}m/${have[3]}Mi, pods ${need_pods} of ${quota_pods:-unlimited}"
done

if ((${#failures[@]} > 0)); then
  echo "check-app-resources: ${#failures[@]} problem(s):" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-app-resources: OK"

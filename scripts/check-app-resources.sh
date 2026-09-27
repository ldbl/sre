#!/usr/bin/env bash
# Guardrail for app resources (2026-09-27: production backend had lower limits than develop, and
# staging the lowest of all). Renders the overlays and fails when:
#   - staging and production differ for an app (staging is the pre-production copy of production)
#   - production gets less than develop for any request or limit
#   - a namespace quota cannot hold the worst case: every app at HPA maxReplicas + its rolling-update
#     surge, plus the Postgres instances - checked for requests and for limits
#
# Runs in pre-commit and in the Flux Diff workflow. Needs kustomize and yq (v4).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

for tool in kustomize yq; do
  command -v "${tool}" >/dev/null || { echo "check-app-resources: ${tool} is required" >&2; exit 1; }
done

envs=(develop staging production)
apps=(backend frontend)
failures=()

app_overlay() { # app env
  if [[ "$1" == frontend ]]; then echo "flux/apps/frontend/overlays/$2"; else echo "flux/apps/$1/$2"; fi
}

# CPU quantity -> millicores ("250m" -> 250, "1" -> 1000, "0.5" -> 500)
to_milli() {
  local q="$1"
  if [[ "${q}" == *m ]]; then echo "${q%m}"; else awk -v v="${q}" 'BEGIN { printf "%d", v * 1000 }'; fi
}

# Memory quantity -> MiB ("256Mi" -> 256, "3Gi" -> 3072, "512Ki" -> 0.5 rounded up)
to_mib() {
  local q="$1"
  case "${q}" in
    *Gi) awk -v v="${q%Gi}" 'BEGIN { printf "%d", v * 1024 }' ;;
    *Mi) echo "${q%Mi}" ;;
    *Ki) awk -v v="${q%Ki}" 'BEGIN { printf "%d", (v + 1023) / 1024 }' ;;
    *) echo "unsupported memory quantity: ${q}" >&2; exit 1 ;;
  esac
}

# yq over a multi-document render prints an empty line and "---" for every document that does not
# match; keep only the real results.
yqs() { yq -N "$1" | sed -e '/^$/d' -e '/^---$/d'; }

render() {
  kustomize build "$1" 2>&1 || { failures+=("$1: kustomize build failed"); echo ""; }
}

# resources APP ENV -> "reqCpu reqMem limCpu limMem" in millicores / MiB
resources() {
  local out
  out="$(render "$(app_overlay "$1" "$2")" | yqs 'select(.kind == "Deployment") | .spec.template.spec.containers[0].resources | [.requests.cpu, .requests.memory, .limits.cpu, .limits.memory] | @tsv')"
  local rc rm lc lm
  IFS=$'\t' read -r rc rm lc lm <<<"${out}"
  echo "$(to_milli "${rc}") $(to_mib "${rm}") $(to_milli "${lc}") $(to_mib "${lm}")"
}

labels=("requests.cpu (m)" "requests.memory (Mi)" "limits.cpu (m)" "limits.memory (Mi)")

# 1 + 2: parity and production >= develop
for app in "${apps[@]}"; do
  read -r -a dev <<<"$(resources "${app}" develop)"
  read -r -a stg <<<"$(resources "${app}" staging)"
  read -r -a prd <<<"$(resources "${app}" production)"
  for i in 0 1 2 3; do
    if [[ "${stg[$i]}" != "${prd[$i]}" ]]; then
      failures+=("${app}: ${labels[$i]} staging=${stg[$i]} but production=${prd[$i]} - staging must match production")
    fi
    if ((prd[i] < dev[i])); then
      failures+=("${app}: ${labels[$i]} production=${prd[$i]} is below develop=${dev[$i]}")
    fi
  done
done

# 3: quota budget per namespace
for env in "${envs[@]}"; do
  need_req_cpu=0 need_req_mem=0 need_lim_cpu=0 need_lim_mem=0
  breakdown=()

  for app in "${apps[@]}"; do
    rendered="$(render "$(app_overlay "${app}" "${env}")")"
    max="$(yqs 'select(.kind == "HorizontalPodAutoscaler") | .spec.maxReplicas' <<<"${rendered}")"
    surge="$(yqs 'select(.kind == "Deployment") | .spec.strategy.rollingUpdate.maxSurge // "25%"' <<<"${rendered}")"
    if [[ "${surge}" == *% ]]; then
      surge="$(awk -v m="${max}" -v p="${surge%\%}" 'BEGIN { s = m * p / 100; printf "%d", (s == int(s)) ? s : int(s) + 1 }')"
    fi
    pods=$((max + surge))
    read -r rc rm lc lm <<<"$(resources "${app}" "${env}")"
    need_req_cpu=$((need_req_cpu + pods * rc)); need_req_mem=$((need_req_mem + pods * rm))
    need_lim_cpu=$((need_lim_cpu + pods * lc)); need_lim_mem=$((need_lim_mem + pods * lm))
    breakdown+=("${app} ${pods}x")
  done

  cnpg="$(render "flux/infrastructure/data/cnpg-clusters/${env}")"
  instances="$(yqs 'select(.kind == "Cluster") | .spec.instances' <<<"${cnpg}")"
  IFS=$'\t' read -r prc prm plc plm <<<"$(yqs 'select(.kind == "Cluster") | .spec.resources | [.requests.cpu, .requests.memory, .limits.cpu, .limits.memory] | @tsv' <<<"${cnpg}")"
  need_req_cpu=$((need_req_cpu + instances * $(to_milli "${prc}"))); need_req_mem=$((need_req_mem + instances * $(to_mib "${prm}")))
  need_lim_cpu=$((need_lim_cpu + instances * $(to_milli "${plc}"))); need_lim_mem=$((need_lim_mem + instances * $(to_mib "${plm}")))
  breakdown+=("postgres ${instances}x")

  quota="$(render "flux/infrastructure/resource-management/${env}")"
  IFS=$'\t' read -r qrc qrm qlc qlm <<<"$(yqs 'select(.kind == "ResourceQuota") | .spec.hard | [."requests.cpu", ."requests.memory", ."limits.cpu", ."limits.memory"] | @tsv' <<<"${quota}")"
  have=("$(to_milli "${qrc}")" "$(to_mib "${qrm}")" "$(to_milli "${qlc}")" "$(to_mib "${qlm}")")
  need=("${need_req_cpu}" "${need_req_mem}" "${need_lim_cpu}" "${need_lim_mem}")
  for i in 0 1 2 3; do
    if ((need[i] > have[i])); then
      failures+=("${env}: worst case (${breakdown[*]}) needs ${labels[$i]}=${need[$i]} but the quota allows ${have[$i]}")
    fi
  done
  echo "  ${env}: worst case (${breakdown[*]}) requests ${need[0]}m/${need[1]}Mi of ${have[0]}m/${have[1]}Mi, limits ${need[2]}m/${need[3]}Mi of ${have[2]}m/${have[3]}Mi"
done

if ((${#failures[@]} > 0)); then
  echo "check-app-resources: ${#failures[@]} problem(s):" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-app-resources: OK"

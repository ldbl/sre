#!/usr/bin/env bash
# Guardrail for the OIDC RBAC (flux/infrastructure/security/rbac) against the Dex GitHub connector.
# Renders the RBAC and fails when a rule is broken:
#   - every Group subject is "<org>:<team>" for an org and team listed in the Dex config
#     (Dex never sends the bare org, so a binding to "safeops-course" silently matches nobody)
#   - write roles (the built-in admin, edit, cluster-admin) are bound only in develop
#   - no role grants Secrets, pods/exec, pods/portforward, a "*" wildcard, or anything but
#     get/list/watch on Flux sources (patching a GitRepository points Flux at another branch -
#     the Chapter 01 incident)
#
# Runs in pre-commit (rbac/ and dex/) and in the Flux Diff workflow. Needs kustomize and yq (v4).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

for tool in kustomize yq; do
  command -v "${tool}" >/dev/null || { echo "check-oidc-rbac: ${tool} is required" >&2; exit 1; }
done

rbac_dir=flux/infrastructure/security/rbac
dex_release=flux/infrastructure/security/dex/release.yaml
failures=()

# shellcheck disable=SC2016 # $org is a yq variable, not shell
# Groups Dex can send: "<org>:<team>" for every team listed under an org of the GitHub connector.
allowed_groups="$(yq -N '.spec.values.config.connectors[] | select(.type == "github") | .config.orgs[]
  | .name as $org | .teams[] | $org + ":" + .' "${dex_release}")"
if [[ -z "${allowed_groups}" ]]; then
  echo "check-oidc-rbac: no org:team found in ${dex_release} - every group binding would match nobody" >&2
  exit 1
fi

rendered="$(kustomize build "${rbac_dir}")"

# 1. Group subjects must be groups Dex actually sends.
while IFS= read -r group; do
  [[ -z "${group}" ]] && continue
  grep -qxF "${group}" <<<"${allowed_groups}" \
    || failures+=("group '${group}' is not an org:team from the Dex config (allowed: $(tr '\n' ' ' <<<"${allowed_groups}"))")
done < <(yq -N '.subjects[]? | select(.kind == "Group") | .name' <<<"${rendered}")

# 2. Write roles only in develop.
while IFS= read -r binding; do
  [[ -z "${binding}" ]] && continue
  failures+=("${binding} binds a write role outside develop")
done < <(yq -N 'select(.kind == "RoleBinding" or .kind == "ClusterRoleBinding")
  | select(.roleRef.name == "admin" or .roleRef.name == "edit" or .roleRef.name == "cluster-admin")
  | select(.kind == "ClusterRoleBinding" or .metadata.namespace != "develop")
  | .kind + "/" + (.metadata.namespace // "cluster") + "/" + .metadata.name' <<<"${rendered}")

# 3. Nothing sensitive in our own roles. (yq: "==" treats "*" as a wildcard, hence test("^\\*$").)
while IFS= read -r role; do
  [[ -z "${role}" ]] && continue
  failures+=("role ${role} grants Secrets, exec/portforward, a wildcard, or a write on Flux sources")
done < <(yq -N 'select(.kind == "Role" or .kind == "ClusterRole")
  | select(.rules | any_c(
      (.resources | any_c(test("^(secrets|pods/exec|pods/portforward|\\*)$")))
      or (.verbs | any_c(test("^\\*$")))
      or ((.apiGroups | any_c(test("^source\\.toolkit\\.fluxcd\\.io$")))
        and (.verbs | any_c(test("^(get|list|watch)$") | not)))
    ))
  | .metadata.name' <<<"${rendered}")

if ((${#failures[@]} > 0)); then
  echo "check-oidc-rbac: FAILED" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-oidc-rbac: OK (groups: $(tr '\n' ' ' <<<"${allowed_groups}"))"

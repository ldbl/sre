#!/usr/bin/env bash
# Guardrail for the OIDC RBAC (flux/infrastructure/security/rbac) and the Dex GitHub connector.
# Renders the RBAC and fails when a rule is broken:
#   - the Dex teams are exactly the fixed allowlist below, and every Group subject is on it
#     (Dex never sends the bare org, so a binding to "safeops-course" silently matches nobody;
#     a fixed list means a new team needs a reviewed change here, not only in Dex and a binding)
#   - write roles (the built-in admin, edit, cluster-admin) are bound only in develop
#   - no role grants Secrets, pods/exec, pods/portforward, a "*" wildcard, or anything but
#     get/list/watch on Flux sources (patching a GitRepository points Flux at another branch -
#     the Chapter 01 incident)
#   - a role that may patch Kustomizations/HelmReleases comes with the field-limiting admission
#     policy oidc-flux-operator-fields in Deny (RBAC alone would allow spec.sourceRef/patches/values)
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
allowed_groups="safeops-course:admins
safeops-course:members"
failures=()

die() {
  echo "check-oidc-rbac: $*" >&2
  exit 1
}

# Every query is a plain assignment so a yq/kustomize failure stops the script instead of
# feeding an empty list to a loop and printing OK.
rendered="$(kustomize build "${rbac_dir}")" || die "kustomize build ${rbac_dir} failed"

# shellcheck disable=SC2016 # $org is a yq variable, not shell
dex_groups="$(yq -N '.spec.values.config.connectors[] | select(.type == "github") | .config.orgs[]
  | .name as $org | .teams[] | $org + ":" + .' "${dex_release}")" || die "cannot read the Dex teams from ${dex_release}"
dex_groups="$(sort <<<"${dex_groups}")"

group_subjects="$(yq -N '.subjects[]? | select(.kind == "Group") | .name' <<<"${rendered}")" \
  || die "cannot read the Group subjects"

write_bindings="$(yq -N 'select(.kind == "RoleBinding" or .kind == "ClusterRoleBinding")
  | select(.roleRef.name == "admin" or .roleRef.name == "edit" or .roleRef.name == "cluster-admin")
  | select(.kind == "ClusterRoleBinding" or .metadata.namespace != "develop")
  | .kind + "/" + (.metadata.namespace // "cluster") + "/" + .metadata.name' <<<"${rendered}")" \
  || die "cannot read the role bindings"

# yq: "==" treats "*" as a wildcard, hence test("^\\*$").
sensitive_roles="$(yq -N 'select(.kind == "Role" or .kind == "ClusterRole")
  | select(.rules | any_c(
      (.resources | any_c(test("^(secrets|pods/exec|pods/portforward|\\*)$")))
      or (.verbs | any_c(test("^\\*$")))
      or ((.apiGroups | any_c(test("^source\\.toolkit\\.fluxcd\\.io$")))
        and (.verbs | any_c(test("^(get|list|watch)$") | not)))
    ))
  | .metadata.name' <<<"${rendered}")" || die "cannot read the roles"

flux_patch_roles="$(yq -N 'select(.kind == "Role" or .kind == "ClusterRole")
  | select(.rules | any_c(
      (.apiGroups | any_c(test("^(kustomize|helm)\\.toolkit\\.fluxcd\\.io$")))
      and (.verbs | any_c(test("^(get|list|watch)$") | not))
    ))
  | .metadata.name' <<<"${rendered}")" || die "cannot read the Flux roles"

field_policy_deny="$(yq -N 'select(.kind == "ValidatingAdmissionPolicyBinding")
  | select(.spec.policyName == "oidc-flux-operator-fields")
  | select(.spec.validationActions | any_c(test("^Deny$"))) | .metadata.name' <<<"${rendered}")" \
  || die "cannot read the admission policy bindings"

# 1. Dex teams = the fixed allowlist; every Group subject on it.
[[ "${dex_groups}" == "${allowed_groups}" ]] \
  || failures+=("Dex teams ($(tr '\n' ' ' <<<"${dex_groups}")) differ from the allowlist ($(tr '\n' ' ' <<<"${allowed_groups}"))")
while IFS= read -r group; do
  [[ -z "${group}" ]] && continue
  grep -qxF "${group}" <<<"${allowed_groups}" \
    || failures+=("group '${group}' is not on the allowlist ($(tr '\n' ' ' <<<"${allowed_groups}"))")
done <<<"${group_subjects}"

# 2. Write roles only in develop.
while IFS= read -r binding; do
  [[ -z "${binding}" ]] && continue
  failures+=("${binding} binds a write role outside develop")
done <<<"${write_bindings}"

# 3. Nothing sensitive in our own roles.
while IFS= read -r role; do
  [[ -z "${role}" ]] && continue
  failures+=("role ${role} grants Secrets, exec/portforward, a wildcard, or a write on Flux sources")
done <<<"${sensitive_roles}"

# 4. Writes on Flux objects only together with the field-limiting policy in Deny.
if [[ -n "${flux_patch_roles}" && -z "${field_policy_deny}" ]]; then
  failures+=("role(s) $(tr '\n' ' ' <<<"${flux_patch_roles}")may write Flux objects, but the admission policy oidc-flux-operator-fields is missing or not in Deny")
fi

if ((${#failures[@]} > 0)); then
  echo "check-oidc-rbac: FAILED" >&2
  printf '  - %s\n' "${failures[@]}" >&2
  exit 1
fi
echo "check-oidc-rbac: OK (groups: $(tr '\n' ' ' <<<"${allowed_groups}"))"

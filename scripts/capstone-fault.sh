#!/usr/bin/env bash
# capstone-fault.sh - a colleague's pull request for the Chapter 23 capstone: one plausible change
# that passes every check and still breaks the platform for its users.
#
# Why: the capstone asks for one change proven in staging and production while the platform is not
# quiet - like every real week, someone else merges something too. This script plays that colleague:
# it picks one of three faults at random, commits it with the message the colleague would write,
# opens a pull request in your repository and merges it once its checks pass. The faults
# (each verified on kind: it passes CI, it breaks, a revert through Git fixes it):
#   f1  sign-ups limited to one a minute (AUTH_REGISTRATIONS_PER_MINUTE) - the pods stay Ready, no
#       alert fires, most sign-ups get 429;
#   f2  the database network policies select a label value no pod has - nothing breaks until the
#       next rollout; then the new backend pods wait at Init for a database they cannot reach;
#   f3  backend CPU cut to 25m - everything works, sign-ups and sign-ins take seconds.
# Which one is not printed: finding it from its symptoms is the exercise. The commit stays in your
# history, like any colleague's.
#
# Usage: make capstone-fault
#        scripts/capstone-fault.sh             (the same)
#        scripts/capstone-fault.sh --local     (commit on a new branch here; no push, no pull request -
#                                               tests, or a repository without GitHub)
#        CAPSTONE_FAULT=f2 scripts/capstone-fault.sh ...   (a chosen fault instead of a random one)
# Needs git; without --local also gh, logged in, and a clean main equal to origin/main.
# Changes: without --local a branch, a pull request and its merge in your GitHub repository; Flux then
# applies main to the cluster. Your working copy is not touched - the change is made in a temporary
# git worktree. With --local, a new branch with one commit in this repository.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The colleague. Fictional: the author of the commit, never a GitHub account.
COLLEAGUE="Mira Koleva <mira.koleva@colleague.invalid>"

# die MESSAGE - print the reason and stop.
die() {
  echo "capstone-fault: $*" >&2
  exit 1
}

# fault_f1 / fault_f2 / fault_f3 - make the fault's change in the current directory (a repository
# root) and set BRANCH, TITLE and BODY: what the colleague would name and write.

fault_f1() {
  local file=flux/apps/backend/base/deployment.yaml
  # Two lines after AUTH_REGISTRATION_ENABLED's value, in the same indentation.
  awk '{ print }
    prev ~ /- name: AUTH_REGISTRATION_ENABLED$/ {
      print "        - name: AUTH_REGISTRATIONS_PER_MINUTE   # bots signed up in bursts - one a minute is plenty"
      print "          value: \"1\""
    }
    { prev = $0 }' "${file}" > "${file}.new"
  mv "${file}.new" "${file}"
  BRANCH="fix/signup-bots"
  TITLE="fix(backend): limit sign-ups to one a minute against bot registrations"
  BODY="We saw bursts of bot sign-ups in the logs. Real people sign up a few times a day, so one a minute per pod is plenty and stops the bursts."
}

fault_f2() {
  local file
  # The Service's name (app-postgres-rw) where the pods' label value (app-postgres) belongs.
  for file in flux/infrastructure/network-policies/base/allow-backend-egress-postgres.yaml \
              flux/infrastructure/network-policies/base/allow-postgres-ingress-backend.yaml; do
    sed 's/values: \[app-postgres, app-postgres-restore\]/values: [app-postgres-rw]/' "${file}" > "${file}.new"
    mv "${file}.new" "${file}"
  done
  BRANCH="chore/netpol-postgres-name"
  TITLE="chore(network-policies): select postgres by its rw name, drop the restore leftover"
  BODY="The backend connects to app-postgres-rw, so the policies now name that. The restore entry was left over from the backup chapter and is not needed any more."
}

fault_f3() {
  local base=flux/apps/backend/base/deployment.yaml develop=flux/apps/backend/develop/kustomization.yaml
  # Only the backend container's CPU - the migrate initContainer above it keeps its own.
  awk '/^      - name: backend$/ { in_backend = 1 }
    in_backend && /cpu: 100m$/ { sub(/100m$/, "25m") }
    in_backend && /cpu: 250m$/ { sub(/250m$/, "25m") }
    { print }' "${base}" > "${base}.new"
  mv "${base}.new" "${base}"
  # Develop's own values, so develop stays no larger than staging and production.
  sed -e 's/value: "50m"/value: "25m"/' -e 's/value: "200m"/value: "25m"/' "${develop}" > "${develop}.new"
  mv "${develop}.new" "${develop}"
  BRANCH="chore/backend-right-size"
  TITLE="chore(backend): right-size CPU - kubectl top shows 1m per pod"
  BODY="kubectl top shows the backend at about 1m CPU per pod. 25m is still 25 times that, and frees the quota for other work."
}

# make_fault - run the chosen (or a random) fault and check that it changed something.
make_fault() {
  local fault="${CAPSTONE_FAULT:-}"
  if [[ -z "${fault}" ]]; then
    fault="f$((RANDOM % 3 + 1))"
  fi
  case "${fault}" in
    f1|f2|f3) "fault_${fault}" ;;
    *) die "CAPSTONE_FAULT must be f1, f2 or f3 (got '${fault}')" ;;
  esac
  [[ -n "$(git status --porcelain)" ]] || die "the change did not apply - has the file changed since this script was written?"
}

# commit_fault - commit everything changed, as the colleague.
commit_fault() {
  git add -A
  git commit -q --author="${COLLEAGUE}" -m "${TITLE}" -m "${BODY}"
}

# run_local - a new branch with the fault, in this repository.
run_local() {
  cd "${repo_root}"
  [[ -z "$(git status --porcelain)" ]] || die "the working copy has uncommitted changes - commit or stash them first"
  make_fault
  git switch -q -c "${BRANCH}"
  commit_fault
  echo "capstone-fault: committed on branch ${BRANCH} (not pushed)"
}

# run_github - the fault as a pull request in your GitHub repository, merged once its checks pass.
run_github() {
  command -v gh >/dev/null || die "gh is required (make check-tools), or use --local"
  gh auth status >/dev/null 2>&1 || die "gh is not logged in (gh auth login)"
  cd "${repo_root}"
  git fetch -q origin main
  [[ "$(git rev-parse main)" == "$(git rev-parse origin/main)" ]] \
    || die "your main is not origin/main - git switch main && git pull, then run it again"

  local work pr checks
  work="$(mktemp -d)"
  # The temporary worktree is removed however the script ends.
  trap 'git -C "${repo_root}" worktree remove --force "${work}" >/dev/null 2>&1; rm -rf "${work}"' EXIT
  git worktree add -q --detach "${work}" origin/main
  cd "${work}"
  make_fault
  git switch -q -c "${BRANCH}"
  commit_fault
  git push -q -u origin "${BRANCH}"
  pr="$(gh pr create --base main --head "${BRANCH}" --title "${TITLE}" --body "${BODY}")"
  echo "capstone-fault: a colleague opened ${pr}"

  # Wait for the repository's checks, as you would for your own pull request (Chapter 05).
  # gh pr checks exits non-zero while checks run, when one failed, and when there are none - only
  # the last one means there is nothing to wait for.
  sleep 15
  if checks="$(gh pr checks "${pr}" 2>&1)" || ! grep -q 'no checks reported' <<<"${checks}"; then
    gh pr checks "${pr}" --watch >/dev/null || die "the pull request's checks failed - nothing merged: ${pr}"
  fi
  gh pr merge "${pr}" --merge --delete-branch >/dev/null
  echo "capstone-fault: and merged it. Flux applies main within a few minutes - carry on with your change."
}

case "${1:-}" in
  --local) run_local ;;
  "") run_github ;;
  -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' ;;
  *) die "unknown argument '$1' (see --help)" ;;
esac

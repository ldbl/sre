#!/usr/bin/env bash
# Pre-command hook for an AI coding agent: a kubectl/flux command must name its
# cluster, and nobody switches the shared current context.
#
# Reads the shell command the agent is about to run on stdin and exits:
#   0 - allowed
#   2 - blocked (the reason is on stderr, for the agent to read)
#
# Why (Chapter 01, rule I): the current context is one line in a kubeconfig
# file shared by every terminal. An agent that runs `kubectl config use-context`
# while reviewing clusters in a second terminal switches your terminal too - you
# checked the context, the agent changed it, your `kubectl apply` goes elsewhere.
# A command that carries --context does not read the shared line at all.
#
# Wiring for Claude Code (.claude/settings.json - see docs/agent-rules.md):
#   PreToolUse, matcher "Bash", command:
#   jq -r '.tool_input.command' | scripts/agent-hooks/kube-context-hook.sh
# Other agents: pipe the command text to this script from their pre-command hook.
#
# Deliberately simple: it splits the command on ; && || | and newlines and looks
# at the first word of each part. It is a seatbelt against the common mistake,
# not a shell parser - `bash -c "..."` or a script that calls kubectl is not seen.
set -euo pipefail

command_text="$(cat)"

block() {
  echo "[kube-context-hook] blocked: $1" >&2
  echo "[kube-context-hook] rule: pass --context <name> on every kubectl/flux command; never change the current context" >&2
  exit 2
}

# One part per line: split on ; && || | and newlines (bash, so BSD and GNU alike).
nl=$'\n'
parts="${command_text//&&/${nl}}"
parts="${parts//||/${nl}}"
parts="${parts//;/${nl}}"
parts="${parts//|/${nl}}"

while IFS= read -r part; do
  # Tabs count as spaces; drop leading spaces and VAR=value prefixes, then take the first word.
  part="${part//$'\t'/ }"
  part="$(printf '%s' "${part}" | sed -E 's/^[[:space:]]+//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//')"
  [[ -z "${part}" ]] && continue
  tool="$(basename -- "${part%% *}")"
  [[ "${tool}" == "kubectl" || "${tool}" == "flux" ]] || continue

  # Changing the shared kubeconfig: never.
  if [[ "${part}" =~ [[:space:]]config[[:space:]]+(use-context|use|set-context|set|delete-context|rename-context|set-cluster|set-credentials|unset)([[:space:]]|$) ]]; then
    block "'${part}' changes the shared kubeconfig"
  fi

  # Reading the kubeconfig itself, or the client version, needs no cluster.
  if [[ "${part}" =~ [[:space:]]config[[:space:]]+(get-contexts|view|current-context)([[:space:]]|$) ]] ||
     [[ "${part}" =~ [[:space:]]version([[:space:]].*)?--client ]]; then
    continue
  fi

  # Everything else talks to a cluster: it must say which one - exactly once
  # (kubectl takes the last one, so a second, empty --context wins), and an empty
  # --context (--context= or --context "") means "use the current context".
  # (grep finds nothing -> exit 1; that is a count of 0, not an error)
  count="$( { grep -o -E '(^|[[:space:]])--context([[:space:]]|=)' <<< "${part}" || true; } | wc -l | tr -d ' ')"
  if (( count > 1 )); then
    block "'${part}' passes --context more than once"
  fi
  if [[ "${part}" =~ [[:space:]]--context(=|[[:space:]]+)([^[:space:]]*) ]]; then
    value="${BASH_REMATCH[2]}"
    if [[ -z "${value}" || "${value}" == '""' || "${value}" == "''" ]]; then
      block "'${part}' passes an empty --context, which means the current context"
    fi
  else
    block "'${part}' does not name its cluster (--context)"
  fi
done <<< "${parts}"

exit 0

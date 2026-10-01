# Rules for Your AI Agent

Instructions for the AI coding agent you use with this platform, one short section per chapter of the
[SafeOps course](https://safeops.work/). Copy the sections of the chapters you have done into your
agent's instruction file (for example `AGENTS.md` or `CLAUDE.md` in your fork), and wire the hooks.

An instruction is attention: the agent follows it until it forgets, or until a new session does not
know it. So every rule says **what enforces it** - a hook, RBAC, CI - or plainly that nothing does.

## How AI works on this platform (Intro)

- **AI proposes; what it may do on its own is decided in advance.** In production an agent acts only
  through narrow, pre-approved actions with only the permissions they need - logged and reversible.
  Everything else is a proposal a human approves.
- **Nothing reaches production unreviewed and untested.** The one exception is an emergency fix during
  an incident, made by the on-call engineer - a person, not an agent - with the break-glass credential.
- **Aim for one failure domain per change.** When a change cannot be split, it still needs a single
  clean rollback.

## Chapter 01 - Verify the target before every write

The current kubectl context is one line in a kubeconfig file that every terminal shares. An agent that
switches it while reviewing clusters in a second terminal switches yours too: you checked the context,
the agent changed it, and your `kubectl apply` goes to another cluster.

| Rule for the agent | What enforces it |
|---|---|
| Never change the current kubectl context (`kubectl config use-context`, `set-context`, ...). | Hook `scripts/agent-hooks/kube-context-hook.sh` blocks it. |
| Every `kubectl` and `flux` command names its cluster with `--context` (and its namespace with `-n`). | The same hook blocks a `kubectl`/`flux` command without `--context`. |
| For a write, run it through the guard, which checks the target and pins it: `scripts/guard-kube-context.sh --context <name> --namespace <ns> -- kubectl apply -f ...` | The guard adds `--context`/`--namespace` to the command itself and refuses a second target inside it (`tests/guard-kube-context.test.sh`). |
| Try a branch on your local kind cluster; never point a shared cluster's Flux at a branch. | On the Hetzner cluster the everyday OIDC identity - and an agent running with it - cannot point Flux at a branch: GitRepositories are read-only, `production` is read-only, and in `flux-system` it can at most suspend or reconcile a Kustomization (RBAC plus an admission policy, checked by `scripts/check-oidc-rbac.sh`). On kind: instruction only. |
| "Ready" is not proof that a change works: report the application's own signals (requests succeeding, queues draining). | Instruction only - nothing enforces it. |

### Wiring the hook (Claude Code)

In your fork's `.claude/settings.json` (needs `jq`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "jq -r '.tool_input.command' | scripts/agent-hooks/kube-context-hook.sh" }
        ]
      }
    ]
  }
}
```

Exit code `2` blocks the command and shows the reason to the agent. Other agents: pipe the command text
to the same script from their pre-command hook. The hook reads the command as text - it is a seatbelt
against the common mistake, not a shell parser: a script that calls `kubectl` inside is not seen.

## Chapter 02 - Apply only the plan a person has read

Terraform changes real infrastructure from its state - its memory of what it built. A saved plan
is exact but gets older every minute, and both the plan and the state hold every secret in plain
text. The agent proposes and plans; a person reads the plan and decides.

| Rule for the agent | What enforces it |
|---|---|
| Never run `terraform apply` without a saved plan that a person has read. Plan with `make kind-plan`, stop, and let the person run `make kind-apply`. | `make kind-apply` (`scripts/guard-terraform-plan.sh`) refuses a missing plan or one older than 60 minutes. A bare `terraform apply` is not blocked locally: instruction only. On Hetzner, CI applies only the approved plan with the hash shown on the run page. |
| Never use `-auto-approve`, and never run `terraform destroy` on your own. | Instruction only - nothing blocks it locally. |
| Never commit, paste or upload a state or a plan file (`*.tfstate*`, `tfplan`, `tfplan.meta`, `*.tfplan`). | `.gitignore`, and the `no-secrets` pre-commit hook plus the Secrets guard CI job refuse them even when added with `git add -f`. Pasting into a chat: instruction only. |
| A plan that destroys or replaces something holding data, or creates something that should already exist: stop and report, do not apply. | Instruction only - the person reading the plan is the check. |
| Check drift before and after a change (`make kind-drift`). Exit `2` with no code change is drift: report it, do not "fix" it by applying. | Instruction only. |

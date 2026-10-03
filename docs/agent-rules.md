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
is exact but gets older every minute, and both the plan and the state can hold sensitive values in
plain text - everything Terraform stores, such as generated passwords. Values passed as `ephemeral`
or write-only (the SOPS key through `data_wo`) and the nodes' SSH key, which never is a Terraform
value, stay out of both. The agent proposes and plans; a person reads the plan and decides.

| Rule for the agent | What enforces it |
|---|---|
| Never run `terraform apply` without a saved plan that a person has read. Plan with `make kind-plan`, stop, and let the person run `make kind-apply`. | `make kind-apply` (`scripts/guard-terraform-plan.sh`) refuses a missing plan or one older than 60 minutes - it does not check that anyone read or approved it; that part is an instruction. A bare `terraform apply` is not blocked locally: instruction only. On Hetzner, CI applies only the plan a person approved, with the hash shown on the run page. |
| Never use `-auto-approve`, and never run `terraform destroy` on your own. | Instruction only - nothing blocks it locally. |
| Never commit, paste or upload a state or a plan file (`*.tfstate*`, `tfplan`, `tfplan.meta`, `*.tfplan`). | `.gitignore`, and the `no-secrets` pre-commit hook plus the Secrets guard CI job refuse them even when added with `git add -f`. Pasting into a chat: instruction only. |
| A plan that destroys or replaces something holding data, or creates something that should already exist: stop and report, do not apply. | Instruction only - the person reading the plan is the check. |
| Check drift before and after a change (`make kind-drift`). Exit `2` means the plan has changes; with no code change of yours the cause is drift, code merged but not applied, or `TF_VAR_*` that differ from the last apply - report it, do not "fix" it by applying. | Instruction only. |

## Chapter 03 - Git is the only way in

Flux keeps the cluster equal to Git: at every reconcile it undoes a change made by hand, creates again
what was deleted, and - where `prune: true` is set, as on every Kustomization here except the one for
CRDs - deletes what was removed from Git. Single objects can opt out with Flux annotations: the
environment namespaces carry `kustomize.toolkit.fluxcd.io/prune: Disabled`, so removing one from Git
never deletes the Namespace - and with it everything inside. The objects inside are still pruned by
their own Kustomizations when they are removed from Git. A fix that is not in Git does not last. A
suspended Kustomization keeps the hand change - and ignores every later commit, security fixes
included, while it still shows `READY True`.

| Rule for the agent | What enforces it |
|---|---|
| A fix to an object Flux manages goes into Git, through a pull request - never `kubectl edit`, `patch` or `apply` on that object. | On Hetzner the OIDC roles are read-only in `staging` and `production`; in `flux-system` too, except that `safeops-course:admins` may patch Kustomizations and HelmReleases to change `spec.suspend` or the reconcile annotations - nothing else. In `develop` and on kind a hand change is allowed, and Flux sets it back at the next reconcile - that undoes it, it does not stop it: instruction only. |
| Never `flux suspend` on your own. If a suspend looks necessary, stop and report: who would suspend what, why, and when it is resumed. | On Hetzner only the `safeops-course:admins` group may suspend, resume or reconcile (`flux/infrastructure/security/rbac`); an agent signed in as an admin can, so for it this is an instruction. On kind: instruction only. |
| Never report the cluster as healthy from `READY` alone: read the `SUSPENDED` column too. | `make smoke-test` fails on a suspended Kustomization. |
| Before proposing a change to a shared `base`, run `flux diff kustomization` for every environment the base feeds, and report every `deleted`. An exit code above `1` means the preview failed, not that nothing changes. | Instruction only. The Flux Diff CI job builds and validates the manifests; it does not compare them with a cluster. |
| Never change how Flux manages an object to get around it. None of these switches Flux off - each does something else: removing its labels only hides the owner (the object is still in Git, and the next reconcile sets the labels back); `prune: false` keeps apply and drift correction running, but objects removed from Git keep running in the cluster; changing `spec.path` or the source changes what Flux applies. | On Hetzner the admission policy `oidc-flux-operator-fields` lets admins change only `spec.suspend` and the reconcile request annotations (`reconcile.fluxcd.io/requestedAt`, `forceAt`, `resetAt`), and GitRepositories are read-only. In Git: the review of the pull request. On kind: instruction only. |

## Chapter 04 - Secrets stay encrypted in Git, and a leaked one is burned

SOPS encrypts the values of a Secret before they are committed; Flux decrypts them in the cluster with
the key in `flux-system/sops-age`. Encrypting needs only the public key in `.sops.yaml`; decrypting
needs the private key (`age.agekey` on kind). A value that was ever pushed in plaintext is public -
rewriting history does not take it back, only replacing it at its source does.

| Rule for the agent | What enforces it |
|---|---|
| A new secret is created only with `scripts/sops-encrypt-secret.sh` (or `sops edit` for an existing file) - never written as plaintext, never added to an encrypted file with a text editor. | The `sops-encrypted` pre-commit hook and the Secrets guard CI job refuse a file under `flux/secrets/` without SOPS metadata or with a plaintext value. The hook runs before the push; CI only before the merge - a pushed branch is already public. |
| Never commit with `--no-verify`. | Instruction only - CI repeats the checks, but after the push. |
| Never read, print, copy or commit a private key (`*.agekey`), and never print decrypted values (`sops -d`, `kubectl get secret -o yaml`) into a chat or a log. | Committing: `.gitignore`, plus the `no-secrets` hook and the Secrets guard CI job (`*.agekey`). Reading and printing: instruction only. |
| Never create, edit or delete `flux-system/sops-age` with `kubectl` - Terraform owns it on both clusters. On kind, a key change is `make kind-plan`, read by a person, then `make kind-apply`. | Instruction only on kind. |
| On Hetzner, a key change is a pull request that raises the default of `sops_age_key_revision` in `infra/terraform/hcloud_cluster/variables.tf` (the key itself is the GitHub secret `SOPS_AGE_KEY`, changed by a person); the Terraform workflow plans it after the merge and applies only after a person approves that plan. | The OIDC roles cannot write Secrets in `flux-system`; the apply job waits for approval in the `production` environment and applies only the approved plan. |
| A value that may have leaked: stop and report. Revoking it at its source and replacing it is a person's decision. | Instruction only. |

## Chapter 05 - A green pull request is only as good as the checks that ran

Every check runs twice: as a hook on the workstation (make install-hooks), and in CI on the pull
request, because `git commit --no-verify` skips the first. GitHub lets a pull request merge when its
*required* checks pass. A required check that failed, was cancelled or never started blocks the merge -
but a job skipped by its `if:` counts as passed, and a workflow skipped by a path or branch filter
leaves its required check waiting forever. Every other check stops nothing: cancelled, skipped or
missing, the merge button stays green. And a Terraform apply is a deliberate, approved run, never a
side effect of a merge.

| Rule for the agent | What enforces it |
|---|---|
| Never `git commit --no-verify`, never `git push --no-verify`, and never amend or force-push a commit that is already pushed. | Amend after push: the `prevent-amend-after-push` hook (it runs even with `--no-verify`). The checks `--no-verify` skips: the Pre-commit CI job on the pull request. Push to `main`: the pre-push branch guard and, on the platform, the ruleset. |
| Report a pull request as ready only when every check ran and passed. A cancelled, skipped or missing check is not green - resolve it, or say which one and why, before calling the pull request ready. | Required checks of the ruleset block the merge until they pass (a job skipped by its `if:` counts as passed); every other check: instruction only. |
| Never start a Terraform apply (Run workflow with "apply"), never approve or reject a deployment. | The environment `production` requires a person's approval; starting the run: instruction only. |
| Never cancel or re-run someone else's workflow run, even one that blocks the queue - report it with its link. | Instruction only. |
| Never change the ruleset, required checks, environments or repository settings. | Needs repository admin rights; for an agent with them: instruction only. |

## Chapter 06 - The default is nothing; every path is written down

In each environment namespace a `default-deny-all` isolates every pod, and one policy per path allows
exactly what the platform needs. Policies only add allowances: one "allow everything" policy undoes all
the others. A pod's labels are its network identity - a pod labelled `app=frontend` gets the frontend's
paths. Flux sets back a changed policy it manages, but never removes a policy created by hand.

| Rule for the agent | What enforces it |
|---|---|
| Change NetworkPolicies only in Git, through a pull request; read `flux diff` for every environment the `base` feeds. Never apply, edit or delete one in an environment namespace by hand. | On Hetzner the OIDC roles may write only in `develop`. Flux sets back a changed or deleted policy it manages - not one created by hand, which stays: instruction only. |
| To fix a blocked connection, propose the exact pair - source labels, target labels, port, both directions - never an empty `from`/`to`, a `podSelector: {}` without ports, or a new `0.0.0.0/0` rule. | The review of the pull request; no check refuses them: instruction only. |
| Diagnose before proposing: run `scripts/np-probe.sh` (DNS and TCP separately) and report which policies select the source and the target. | Instruction only. |
| Never give a pod the labels of another application to get through a policy. | Instruction only; on Hetzner pods can be created only in `develop`. |
| Experiments go into the namespace `lab`, and what you created there is deleted afterwards. | Instruction only. |

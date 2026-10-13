# Platform Handover

<!-- Chapter 23 capstone. Copy this file to docs/handover.md and replace every placeholder. A section
     that does not apply says why, in a sentence - a placeholder never stays: make capstone-check
     refuses the handover while one is left.
     Keep four kinds of statement apart, as in a postmortem (Chapter 15): what was observed (with its
     evidence), what is assumed, what made it possible, and what will change. The reader takes over
     tomorrow and was not there: every claim points to something they can check again. -->

- **Date (UTC):** TODO
- **From:** TODO (you) **To:** TODO (who runs the platform after you)
- **Repository and revision handed over:** TODO (your fork, and `git rev-parse origin/main`)

## The Platform in One Paragraph

TODO: what runs where, how a change reaches it, what protects it - for someone who knows Kubernetes
but not this platform.

## What Changed This Week

One row per pull request, yours and others'. Level: proven / proven with a hint (which hint) /
not proven yet.

| Change | Pull request | Proven by (the check, and the evidence below) | Level |
|---|---|---|---|
| Display names in staging | TODO | TODO | TODO |
| Display names in production | TODO | TODO | TODO |
| A colleague's change | TODO | TODO | TODO |
| Its fix | TODO | TODO | TODO |

## Evidence on the Users' Path

The sign-up and sign-in of each environment, after its change - status, time and the returned user,
pasted as the commands printed them:

```text
TODO: staging
TODO: production
```

## The Colleague's Change

- **What you observed first, and when (UTC):** TODO
- **What you assumed, and how you checked it:** TODO
- **The evidence that tied the symptom to the change:** TODO
- **The fix, its pull request, and the proof it worked:** TODO
- **Why no check caught it, and what would:** TODO

## The AI Agent's Proposal

- **The proposal, in one sentence:** TODO
- **Decision (accepted, rejected, or accepted in part):** TODO
- **The reason, with the evidence or the rule behind it:** TODO

## Acceptance Criteria

The output of `make capstone-check`, as printed, and the revision it ran against:

```text
TODO
```

## How to Run It

- **Where a change goes in, and how it reaches the cluster:** TODO
- **What alerts, and who it reaches:** TODO
- **The runbooks, and which one for what:** TODO
- **Backups - the last proven restore, RTO and RPO as measured:** TODO
- **Credentials - where the registry is, what is due next:** TODO

## What It Does Not Protect Against

TODO: the known limits, each with what it would cost to change - a single worker, what the error
budget does not count, what reaches nobody on kind, anything this week showed you.

## Before Real Users

TODO: what has to change before anyone depends on it - each item with why, and roughly what it costs.

## Open Items

| Item | Owner | Due |
|---|---|---|
| TODO | TODO | TODO |

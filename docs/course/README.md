# Guardrails-First Course Materials

## Current Status

This directory is in an early scaffold stage.

Available now:
- `00-intro-ai-as-junior.md` - course framing and mental model.
- `CURRICULUM.md` - approved 13-chapter course structure.
- `_lesson-template.md` - standard lesson structure for guardrails-first labs.
- `chapter-01-introduction/README.md` - first complete guardrails lesson with demo commands.
- `chapter-02-iac/{README,lab,quiz}.md` - first IaC chapter draft with guarded Terraform workflow.
- `chapter-03-secrets-management/{README,lab,quiz}.md` - SOPS lesson pack for `encrypt -> commit -> Flux decrypt/apply`.
- `chapter-04-gitops/{README,lab,quiz}.md` - GitOps promotion pack (`develop -> staging -> production`) with rollback drill.
- `chapter-05-network-policies/{README,lab,quiz}.md` - isolation pack with default deny, DNS allow, ingress allow, and blocked-traffic debug.
- `chapter-06-security-context/{README,lab,quiz}.md` - pod hardening pack (non-root, read-only root FS, dropped caps, seccomp).
- `chapter-07-resource-management/{README,lab,quiz}.md` - requests/limits, quota/limitrange, QoS and OOM analysis pack.
- `chapter-08-availability-engineering/{README,lab,quiz}.md` - HPA/PDB availability pack with drain preflight checks.
- `chapter-09-observability/{README,lab,runbook-incident-debug,quiz}.md` - metrics/logs/traces workflow with incident debug path.
- `chapter-10-backup-restore/{README,lab,runbook,quiz}.md` - CNPG backup/restore basics with simulation workflow.
- `chapter-11-controlled-chaos/{README,lab,runbook-game-day,scorecard,quiz}.md` - deterministic failure drills + guarded Chaos Monkey in `develop`.
- `chapter-12-ai-assisted-sre-guardian/{README,lab,runbook-guardian,quiz}.md` - draft guardian chapter mapped to `k8s-ai-monitor`.
- `chapter-13-24-7-production-sre/{README,lab,runbook-oncall,postmortem-template,quiz}.md` - on-call lifecycle and blameless operations module.
- chapter directories under `chapter-*` - work-in-progress placeholders and migration targets.

Not available yet:
- complete lecture notes per chapter
- step-by-step labs with solutions
- quizzes/knowledge checks per chapter

## Course Goal

Teach practical DevOps/SRE workflows where AI increases speed without increasing production risk.

Core model:
- AI proposes.
- Humans decide.
- Guardrails enforce safe execution paths.

See `../ai-code-of-conduct.md` for repository-wide rules.

## Planned Structure

The canonical structure is now the 13-chapter program in `CURRICULUM.md`:
1. Production Mindset & Guardrails
2. Infrastructure as Code (IaC)
3. Secrets Management (SOPS)
4. GitOps & Version Promotion
5. Network Policies (Production Isolation)
6. Security Context & Pod Hardening
7. Resource Management & QoS
8. Availability Engineering (HPA + PDB)
9. Observability
10. Backup & Restore Basics
11. Controlled Chaos
12. AI-Assisted SRE Guardian
13. 24/7 Production SRE

## Authoring Workflow

1. Start each new chapter from `_lesson-template.md`.
2. Keep each lesson tied to one failure mode and one guardrail story.
3. Include:
   - unsafe path (what breaks and why)
   - safe path (checks, approvals, rollback)
   - reproducible demo commands
4. Prefer deterministic labs that can run on local kind and map to Hetzner workflows.

## Next Recommended Content

1. `chapter-01-introduction`: first full lesson using the template.
2. `chapter-02-iac`: production IaC lab (plan/review/apply + safe destroy).
3. `chapter-03-secrets-management`: add review checklist and optional key-rotation drill extension.
4. `chapter-12-ai-assisted-sre-guardian`: wire Flux deployment + chaos event mapping for guardian MVP.
5. `chapter-13-24-7-production-sre`: run one full capstone incident and finalize operating metrics.

## Pending Decisions

1. Final course duration estimate (hours).
2. Target learner level (mid/senior split).
3. Concrete lab depth per chapter.
4. Opening and closing story arc for delivery impact.

## Notes

If a chapter folder is present but empty, treat it as planned scope, not completed material.

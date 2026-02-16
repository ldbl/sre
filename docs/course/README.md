# Guardrails-First Course Materials

## Current Status

This directory is in an early scaffold stage.

Available now:
- `00-intro-ai-as-junior.md` - course framing and mental model.
- `_lesson-template.md` - standard lesson structure for guardrails-first labs.
- chapter directories `chapter-01-*` through `chapter-17-*` - currently placeholders for upcoming lesson content.

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

- Part 1 (`chapter-01` to `chapter-04`): foundations and IaC baseline
- Part 2 (`chapter-05` to `chapter-07`): GitOps and CI/CD flow
- Part 3 (`chapter-08` to `chapter-11`): observability and incident response
- Part 4 (`chapter-12` to `chapter-13`): security and quality gates
- Part 5 (`chapter-14` to `chapter-16`): advanced operations and readiness
- Part 6 (`chapter-17`): capstone

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
2. `chapter-05-gitops`: image tagging + promotion flow aligned with `docs/gitops-workflow.md`.
3. `chapter-08-metrics`: dashboard + alert triage lab from current Flux observability setup.

## Notes

If a chapter folder is present but empty, treat it as planned scope, not completed material.

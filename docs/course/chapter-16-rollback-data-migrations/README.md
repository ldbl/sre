# Chapter 16: Rollback and Data Migrations (Advanced)

## Why This Chapter Exists

Application rollback is easy only when database state is compatible.
Most production rollback failures happen at the boundary between application version and schema version.

This chapter defines a safe migration discipline:
- backward-compatible schema first
- application rollout second
- destructive schema changes last
- explicit rollback windows and feature flag gates

## Learning Objectives

By the end of this chapter, learners can:
- explain expand/contract migration strategy
- design rollback-safe deploy sequence for app + schema
- execute a migration incident drill with evidence capture
- define break-glass rules for failed migrations

## Current Project State

- backend service currently does not depend on production DB reads/writes for core flow
- chapter uses migration workflow simulation on CNPG/PostgreSQL targets
- when backend login + DB flow is added, this chapter becomes mandatory release gate

## The Incident Hook

A release includes application code and schema migration in one step.
Migration drops/renames a column used by previous app version.
New deployment fails health checks; rollback of application image succeeds, but old app cannot read data anymore.
Incident duration expands because "app rollback" alone cannot recover service.

## What AI Would Propose (Brave Junior)

- "Apply migration and deploy together in one PR."
- "If deploy fails, just rollback image tag."
- "Skip feature flags to reduce complexity."

Why this sounds reasonable:
- fewer moving parts in one release
- fast visible progress

## Why This Is Dangerous

- schema and application coupling creates irreversible rollback paths
- destructive changes remove safety window
- partial rollout can leave mixed-version traffic against incompatible schema

## Guardrails That Stop It

- expand/contract strategy only
- migration scripts must be idempotent and reviewed
- app rollout uses feature flags for behavior gating
- rollback plan includes data compatibility checks
- destructive DDL only after verification window and explicit approval

## Repository Mapping

- data platform baseline: `flux/infrastructure/data/cnpg-clusters/`
- backup/restore baseline: `docs/course/chapter-10-backup-restore/`
- promotion baseline: `docs/course/chapter-04-gitops/`

## Safe Workflow (Step-by-Step)

1. Create expand migration (additive only).
2. Deploy migration job and verify schema compatibility.
3. Deploy app with new code path behind feature flag (flag off).
4. Enable flag gradually and monitor SLO/error budget.
5. Keep rollback window open until confidence threshold.
6. Run contract migration only after explicit approval.

## Lab Files

- `lab.md`
- `runbook-rollback-migrations.md`
- `quiz.md`

## Done When

- learner can run migration drill with rollback-safe sequence
- learner can distinguish app rollback vs data rollback limits
- learner can define no-go conditions before destructive migration

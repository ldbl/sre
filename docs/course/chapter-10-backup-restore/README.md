# Chapter 10: Backup & Restore Basics

## Why This Chapter Exists

Backups are useful only if restore is tested and repeatable.
This chapter uses CloudNativePG as real stateful target with PVC-backed PostgreSQL.

## Data Plane Choice

CloudNativePG setup in this repo:
- operator: `flux/infrastructure/data/cnpg-operator/`
- clusters: `flux/infrastructure/data/cnpg-clusters/{develop,staging,production}/`
- each environment has dedicated `Cluster` + `ScheduledBackup`

## Backup Credential Model

Before SOPS integration, bootstrap credentials are created by Terraform:
- secret name: `cnpg-backup-s3`
- namespaces: `develop`, `staging`, `production`
- keys: `ACCESS_KEY_ID`, `ACCESS_SECRET_KEY`, `BUCKET` (+ optional `ENDPOINT`, `REGION`)

Terraform source:
- `infra/terraform/hcloud_cluster/main.tf`
- `infra/terraform/hcloud_cluster/variables.tf`

## Guardrails

- No backup without tested restore path.
- Backup target credentials must be secret-managed (SOPS path next).
- Recovery drills must run in non-production first.
- Evidence is required: backup status + restore validation query.

## Lab Files

- `lab.md`
- `runbook.md`
- `quiz.md`

## Done When

- learner can verify scheduled backups are running
- learner can execute one manual backup
- learner can perform restore simulation and validate recovered data

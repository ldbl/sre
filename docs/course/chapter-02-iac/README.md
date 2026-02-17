# Chapter 02: Infrastructure as Code (IaC)

## Why This Chapter Exists

In production, infrastructure mistakes are expensive and fast-moving.
IaC is not only about automation speed. It is about:
- repeatability
- reviewability
- rollback paths
- controlled blast radius

This chapter introduces a guardrails-first Terraform workflow for Kubernetes platforms.

## Learning Objectives

By the end of this chapter, learners can:
- explain module boundaries and Terraform folder structure in this repo
- run a safe `plan -> review -> apply` workflow
- explain why remote state and locking are non-negotiable in team environments
- detect drift and decide whether to reconcile or rollback
- execute safe destroy practices with explicit scope checks

## Repo Mapping

Relevant paths:
- `infra/terraform/hcloud_cluster/`
- `infra/terraform/kind_cluster/`
- `scripts/guard-terraform-plan.sh`
- `docs/course/chapter-02-iac/review-checklist.md`
- `docs/course/chapter-02-iac/drift-playbook.md`
- `docs/hetzner.md`

## Core Concepts

1. Terraform structure and modules
- root configuration should stay thin and readable
- provider/module versions must be pinned
- reusable logic belongs in modules, not copy/paste blocks

2. Remote state and locking
- shared state enables team collaboration
- locking prevents concurrent apply corruption
- backend config is part of production reliability

3. IAM and RBAC principles
- least privilege by default
- separate read/plan/apply responsibilities
- no broad credentials for automation or AI tooling

4. Drift detection
- drift = actual infra != declared infra
- detect drift before making unrelated changes
- never hide drift by batching many changes together

5. Safe destroy
- destroy is valid, but only with explicit scope
- always verify workspace, targets, and dependency impact
- create a rollback/recreate plan before destructive actions

## Chapter Flow

1. Read this chapter and `lab.md`.
2. Run the lab with guardrail scripts.
3. Validate expected outputs and complete `quiz.md`.

## Anti-Patterns to Avoid

- Running `terraform apply` without reviewed `plan`.
- Applying from stale plan output.
- Sharing one credential set across all environments.
- Using destroy in ambiguous context.

## Next Chapter

Continue with Chapter 03 (Secrets Management with SOPS).

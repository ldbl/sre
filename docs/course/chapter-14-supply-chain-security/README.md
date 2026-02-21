# Chapter 14: Supply Chain Security (Advanced)

## Why This Chapter Exists

A successful CI build does not guarantee runtime trust.
This chapter enforces a production rule: only verifiable artifacts may run.

The supply-chain baseline in this course is:
- immutable artifact identity (digest or immutable tag)
- SBOM generation
- image signing and attestation
- cluster-side verification before admission

## Learning Objectives

By the end of this chapter, learners can:
- explain why "build once, promote many" is required for provenance
- generate and verify SBOM/signature evidence for one artifact
- run policy rollout in `Audit -> Enforce` phases in non-production
- document deny evidence and remediation path

## The Incident Hook

An urgent fix is rebuilt from a developer workstation and pushed with a familiar tag.
The deploy appears normal, but during incident triage the team cannot prove which workflow produced the binary.
Dependency baseline, SBOM lineage, and signer identity are unclear.
Rollback confidence drops because artifact trust is uncertain.

## What AI Would Propose (Brave Junior)

- "Rebuild locally and push now."
- "Skip signing for this release only."
- "Use mutable tags for faster retagging."

Why this sounds reasonable:
- shortest time-to-deploy
- less CI friction under pressure

## Why This Is Dangerous

- No cryptographic provenance at runtime.
- Rebuild variance breaks "tested artifact == deployed artifact".
- Incident response becomes trust investigation instead of recovery.

## Guardrails That Stop It

- Promote by artifact identity, not rebuild.
- SBOM is generated per release artifact.
- Signatures/attestations are verified before runtime admission.
- Verification policy starts in `Audit`, then moves to `Enforce`.

## Current Platform State

- Kyverno engine is active: `flux/infrastructure/policy/kyverno/`
- Chapter 14 policy pack is scaffolded but inactive by default:
  `flux/infrastructure/policy/packs/chapter-14-supply-chain/`
- This allows safe engine rollout before strict enforcement.

## Repository Mapping

- Engine: `flux/infrastructure/policy/kyverno/`
- Pack templates:
  - `flux/infrastructure/policy/packs/chapter-14-supply-chain/verify-images.example.yaml`
  - `flux/infrastructure/policy/packs/chapter-14-supply-chain/verify-attestations.example.yaml`
- App references: `flux/apps/**/deployment.yaml`
- Promotion model baseline: `docs/course/chapter-04-gitops/`

## Safe Workflow (Step-by-Step)

1. Pick immutable artifact reference.
2. Generate SBOM and sign/attest in CI-compatible flow.
3. Verify signature and attestation locally.
4. Apply verify policy in `Audit` mode in `develop`.
5. Observe reports/deny evidence and tune constraints.
6. Move selected rules to `Enforce` only after stable audit results.

## Lab Files

- `lab.md`
- `runbook-supply-chain.md`
- `quiz.md`

## Done When

- learner proves artifact identity and provenance with command evidence
- learner demonstrates policy behavior in `Audit` and `Enforce`
- learner can handle unsigned/untrusted artifact deny without disabling guardrails

## Handoff

Continue with Chapter 15 (Admission Policy Guardrails) for broader runtime policy enforcement beyond signatures.

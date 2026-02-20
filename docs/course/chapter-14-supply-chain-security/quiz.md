# Quiz: Chapter 14 (Supply Chain Security)

## Questions

1. Why is "build once, promote many" a core supply-chain guardrail?

2. Why is digest reference stronger than mutable tag reference?

3. What does image signing prove that SBOM alone does not?

4. Why should verification policy start in `Audit` for non-production rollout?

5. Which statement is correct?
- A) If CI passes, runtime signature verification is redundant.
- B) Admission verification can stop untrusted artifacts before execution.
- C) Mutable tags improve incident forensics.

6. What is the operational difference between `Audit` and `Enforce` in Kyverno?

7. Name two pieces of evidence required after a denied artifact admission.

8. Signature verification fails during urgent release. Best response:
- A) disable policy globally and continue
- B) pause promotion, fix signing path, redeploy trusted artifact
- C) bypass only for production

9. Why is attestation verification useful even when signatures pass?

10. Complete the guardrail:
- A) no trusted signature, no runtime admission
- B) internal services can skip provenance controls
- C) tag naming convention is enough trust proof

## Answer Key (Short)

1. It preserves tested artifact identity and provenance across environments.
2. Digest is immutable and uniquely identifies exact artifact content.
3. Signing proves origin/integrity; SBOM describes content.
4. It allows safe tuning before hard enforcement.
5. B
6. `Audit` reports violations; `Enforce` blocks violating admissions.
7. Policy/rule name and event/deny message with artifact reference.
8. B
9. It proves required metadata exists and matches policy expectations.
10. A

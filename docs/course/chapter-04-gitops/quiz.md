# Quiz: Chapter 04 (GitOps & Version Promotion)

## Questions

1. Why is "promotion instead of rebuild" a core production guardrail?

2. Which tag families are expected in each namespace?
- develop:
- staging:
- production:

3. What is the risk of deploying mutable `latest` tags to production?

4. In this model, what triggers production image creation?
- A) push to `develop`
- B) push to `main`
- C) manual promotion workflow

5. What does Flux `ImageUpdateAutomation` add from an audit perspective?

6. Where should you look first if production does not pick a newly promoted tag?

7. What is the preferred rollback path?
- A) edit deployment live in cluster
- B) revert Git commit and let Flux reconcile
- C) disable Flux and patch manifests manually

8. Why is `kubectl rollout undo` considered emergency-only here?

9. Name two hard stop conditions before approving a production promotion.

10. Complete the statement: AI should ______ in this flow.
- A) auto-promote directly to production when tests pass
- B) propose and assist, while humans approve and guardrails enforce
- C) bypass image policy regex checks for urgent fixes

## Answer Key (Short)

1. It preserves tested artifact lineage and removes rebuild variance across environments.
2. `develop-*`, `staging-*`, `production-*`.
3. Loss of immutability and traceability; rollback and incident audit become unreliable.
4. C
5. Git commit history for image tag changes with clear traceability.
6. `ImageRepository`/`ImagePolicy` status and image automation logs in `flux-system`.
7. B
8. It can create drift from Git and must be reconciled back immediately.
9. Example: non-immutable/mutable tag usage; policy mismatch allowing wrong env tags; unclear rollback path.
10. B

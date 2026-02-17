# Quiz: Chapter 03 (Secrets Management with SOPS)

## Questions

1. Why is `git revert` not enough after a plaintext secret is committed?

2. What is the role of `sops-age` in `flux-system`?

3. Which file defines how secrets are encrypted with age in this repo?

4. In the Chapter 03 lab flow, what is the correct sequence?
- A) commit plaintext -> push -> encrypt later
- B) encrypt -> commit -> Flux decrypt/apply
- C) create secret directly in cluster and never track in Git

5. Name two hard stop conditions before committing secret changes.

6. You pushed an encrypted secret file, but `backend-secrets` does not appear in namespace `develop`. What is the first manifest-level check?

7. What command helps verify that Flux decryption/apply for develop secrets is healthy?

8. If a secret value is exposed in Git history, list two immediate response actions.

9. Why is storing `age.agekey` in Git considered a critical violation?

10. Which is the preferred statement for this course?
- A) AI can auto-fix secret incidents in production
- B) AI suggests, humans approve, guardrails enforce safe execution
- C) If deployment is blocked, bypass encryption temporarily

## Answer Key (Short)

1. Because the value is already exposed in history/clones/logs; revert does not un-leak it.
2. Holds the age private key used by Flux to decrypt SOPS-encrypted manifests.
3. `.sops.yaml`
4. B
5. Example: plaintext values in secret manifest; committed private key material; wrong namespace/target.
6. Check `flux/secrets/develop/kustomization.yaml` includes `backend-secrets.yaml`.
7. `kubectl -n flux-system get kustomization secrets-develop` (and/or `describe`).
8. Rotate affected credentials; start containment/audit of exposure scope.
9. It gives decryption capability for encrypted secrets and collapses the whole trust model.
10. B

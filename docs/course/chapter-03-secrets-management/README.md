# Chapter 03: Secrets Management (SOPS)

## Why This Chapter Exists

Plaintext secrets in Git are a production incident waiting to happen.
This chapter establishes one safe path:
- secrets are encrypted before commit
- Flux decrypts in-cluster with `sops-age`
- key material is never committed

## The Incident Hook

A teammate commits a plaintext API key to fix a failing deploy quickly.
The key is exposed in Git history, CI logs, and local clones.
The rollback is not enough because the secret is already leaked.
Response now includes rotation, audit, and cross-team coordination under pressure.

## What AI Would Propose (Brave Junior)

- "Create Kubernetes Secret YAML and push it fast."
- "We can encrypt later."

Why this sounds reasonable:
- fastest path to unblock deployment
- appears reversible via `git revert`

## Why This Is Dangerous

- Git history is durable; reverting does not un-leak the value.
- Secret fan-out is unknown (clones, caches, logs, screenshots).
- Blast radius includes external integrations using that credential.

## Guardrails That Stop It

- No plaintext secrets under `flux/secrets/**`.
- `sops-age` secret must exist in `flux-system` before relying on encrypted manifests.
- Only encrypted files are allowed in PRs.
- Secret rotation plan is mandatory after any exposure.
- Local `no-secrets` pre-commit hook blocks common sensitive files before commit.
- Local `flux-kustomize-validate` pre-commit hook catches broken Flux Kustomize wiring before commit.

## Repo Mapping

- `.sops.yaml`
- `flux/secrets/`
- `flux/bootstrap/flux-system/secrets.yaml`
- `scripts/sops-setup.sh`
- `scripts/sops-encrypt-secret.sh`

## Lab Goal (Day 4 Deliverable)

Run the baseline flow end-to-end:
1. Encrypt secret for `develop`.
2. Commit/push encrypted manifest.
3. Let Flux decrypt and apply it.
4. Verify secret exists in cluster without exposing values.

Lab file:
- `lab.md`
- `quiz.md`

## Safe Workflow (Step-by-Step)

1. Verify prerequisites:

```bash
command -v sops
command -v age
kubectl get ns flux-system
```

2. Ensure decryption key exists in cluster:

```bash
kubectl -n flux-system get secret sops-age
```

If missing, create/setup it via:

```bash
scripts/sops-setup.sh --create-secret
```

3. Create encrypted secret manifest:

```bash
scripts/sops-encrypt-secret.sh develop backend-secrets
```

4. Include secret in develop kustomization:

File to edit: `flux/secrets/develop/kustomization.yaml`

Uncomment:

```yaml
- backend-secrets.yaml
```

5. Commit and push:

```bash
git add flux/secrets/develop/backend-secrets.yaml flux/secrets/develop/kustomization.yaml
git commit -m "chapter-03: add encrypted backend secret for develop"
git push
```

6. Verify Flux decrypt/apply:

```bash
kubectl -n flux-system get kustomization secrets-develop
kubectl -n flux-system describe kustomization secrets-develop
kubectl -n develop get secret backend-secrets
```

## Verification Checklist

- `backend-secrets.yaml` in Git is encrypted (`ENC[...]` values).
- `secrets-develop` Kustomization is Ready.
- `backend-secrets` exists in namespace `develop`.
- No plaintext values appear in committed diff.
- Local pre-commit `no-secrets` check passes before commit.
- Local pre-commit `flux-kustomize-validate` check passes before commit.

## Anti-Patterns

- Committing plaintext then "fixing" with later encryption.
- Sharing `age.agekey` through chat/email or committing it.
- Reusing one leaked credential across all environments.

## Done When

- Learner can explain why Git revert is not enough after secret leak.
- Learner can run `encrypt -> commit -> Flux decrypt/apply` without plaintext exposure.
- Learner can identify where decryption fails (`sops-age`, `.sops.yaml`, or Kustomization wiring).

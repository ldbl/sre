# Lab: Encrypted Secret -> Flux Decrypt -> Cluster Apply

## Goal

Execute a safe secrets workflow for `develop`:
- create/update encrypted secret manifest with SOPS
- commit only encrypted content
- verify Flux decrypts and applies secret in-cluster

## Guardrail Companion

- `README.md` (incident context and safe path)
- `flux/secrets/README.md` (SOPS/age mechanics)

## Prerequisites

- `sops`, `age`, `kubectl` installed
- access to a cluster with Flux installed
- `flux-system` namespace exists
- `sops-age` secret exists in `flux-system`

Quick checks:

```bash
command -v sops
command -v age
kubectl get ns flux-system
kubectl -n flux-system get secret sops-age
```

## Step 1: Context Check

```bash
pwd
ls -la flux/secrets/develop
```

Expected:
- you are in `sre/`
- `flux/secrets/develop/kustomization.yaml` exists

## Step 2: Create or Update Encrypted Secret

```bash
scripts/sops-encrypt-secret.sh develop backend-secrets
```

Expected:
- file exists: `flux/secrets/develop/backend-secrets.yaml`
- file contains encrypted fields (`ENC[`), not plaintext values

## Step 3: Wire Secret into Kustomization

Edit `flux/secrets/develop/kustomization.yaml` and ensure:

```yaml
resources:
  - uptrace-secrets.yaml
  - backend-secrets.yaml
```

Hard stop conditions (do not commit):
- any plaintext secret value in `backend-secrets.yaml`
- committed `age.agekey` or any private key material
- wrong namespace in secret metadata

## Step 4: Commit Encrypted Changes

```bash
git add flux/secrets/develop/backend-secrets.yaml flux/secrets/develop/kustomization.yaml
git diff --cached
```

Review expectation:
- encrypted payload only (`ENC[...]`)
- no plaintext credentials in staged diff

Then:

```bash
git commit -m "chapter-03: add/update encrypted backend secret for develop"
git push
```

## Step 5: Verify Flux Reconciliation

```bash
kubectl -n flux-system get kustomization secrets-develop
kubectl -n flux-system describe kustomization secrets-develop
kubectl -n develop get secret backend-secrets
```

Expected:
- `secrets-develop` is `Ready=True`
- secret `backend-secrets` exists in namespace `develop`

## Failure Scenarios

1. Missing `sops-age` secret
- symptom: decryption/reconcile errors in `secrets-develop`
- action: create key secret in `flux-system`, then reconcile again

2. Secret file not referenced in kustomization
- symptom: Flux healthy, but `backend-secrets` not created
- action: add `backend-secrets.yaml` to `flux/secrets/develop/kustomization.yaml`

3. Plaintext committed by mistake
- symptom: sensitive data visible in Git diff/history
- action: incident response flow (rotate credential, purge/contain exposure, audit access)

## Done When

- learner can complete `encrypt -> commit -> Flux decrypt/apply` in `develop`
- learner can explain why encrypted-at-rest in Git is mandatory
- learner can diagnose the three failure scenarios above

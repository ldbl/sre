# Lab: Admission Guardrails in Audit and Enforce Modes (Advanced)

## Goal

Run a practical Kyverno workflow in `develop`:
- enable starter policies in `Audit`
- trigger and inspect violations
- switch one policy to `Enforce`
- validate deny -> fix -> admit behavior

## Prerequisites

- Kyverno engine running in cluster
- access to `develop` namespace
- starter templates available:
  - `flux/infrastructure/policy/packs/chapter-15-admission-guardrails/disallow-latest-tag.example.yaml`
  - `flux/infrastructure/policy/packs/chapter-15-admission-guardrails/require-security-context.example.yaml`
  - `flux/infrastructure/policy/packs/chapter-15-admission-guardrails/require-requests-limits.example.yaml`

Quick checks:

```bash
kubectl -n kyverno get pods
kubectl get ns develop
kubectl get cpol
```

## Step 1: Apply Starter Policies in Audit Mode

```bash
kubectl apply -f flux/infrastructure/policy/packs/chapter-15-admission-guardrails/disallow-latest-tag.example.yaml
kubectl apply -f flux/infrastructure/policy/packs/chapter-15-admission-guardrails/require-security-context.example.yaml
kubectl apply -f flux/infrastructure/policy/packs/chapter-15-admission-guardrails/require-requests-limits.example.yaml
```

Confirm mode is `Audit`:

```bash
kubectl get cpol disallow-latest-tag-example -o jsonpath='{.spec.validationFailureAction}'; echo
kubectl get cpol require-security-context-example -o jsonpath='{.spec.validationFailureAction}'; echo
kubectl get cpol require-requests-limits-example -o jsonpath='{.spec.validationFailureAction}'; echo
```

## Step 2: Apply a Risky Workload (Expected Audit Violation)

Create risky manifest:

```bash
cat <<'YAML' >/tmp/ch15-risky-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ch15-risky
  namespace: develop
spec:
  containers:
    - name: app
      image: nginx:latest
YAML

kubectl apply -f /tmp/ch15-risky-pod.yaml
```

Inspect audit signals:

```bash
kubectl -n develop get events --sort-by=.lastTimestamp | tail -n 30
kubectl get policyreport -A | rg develop
```

## Step 3: Switch One Policy to Enforce

```bash
kubectl patch cpol disallow-latest-tag-example \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Enforce"}}'
```

Re-apply risky manifest (expected deny):

```bash
kubectl delete -f /tmp/ch15-risky-pod.yaml --ignore-not-found=true
kubectl apply -f /tmp/ch15-risky-pod.yaml
```

## Step 4: Remediate and Re-Apply

Create compliant manifest:

```bash
cat <<'YAML' >/tmp/ch15-compliant-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ch15-compliant
  namespace: develop
spec:
  securityContext:
    runAsNonRoot: true
  containers:
    - name: app
      image: nginx:1.27.5
      securityContext:
        runAsNonRoot: true
        allowPrivilegeEscalation: false
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 256Mi
YAML

kubectl apply -f /tmp/ch15-compliant-pod.yaml
kubectl -n develop get pod ch15-compliant
```

## Step 5: Controlled Cleanup

Return policy to `Audit` for shared environments:

```bash
kubectl patch cpol disallow-latest-tag-example \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'
```

Cleanup resources:

```bash
kubectl -n develop delete pod ch15-risky ch15-compliant --ignore-not-found=true
rm -f /tmp/ch15-risky-pod.yaml /tmp/ch15-compliant-pod.yaml
```

Optional policy cleanup:

```bash
kubectl delete cpol \
  disallow-latest-tag-example \
  require-security-context-example \
  require-requests-limits-example \
  --ignore-not-found=true
```

## Evidence to Capture

- policy mode before/after (`Audit`/`Enforce`)
- audit event/policyreport for risky manifest
- deny message in `Enforce`
- successful admit of compliant manifest

## Hard Stop Conditions

- disabling Kyverno deployment instead of fixing manifests
- creating namespace-wide permanent exception
- moving all policies to `Enforce` in production without audit data

## Done When

- learner demonstrates `Audit -> Enforce -> Audit` safely
- learner can explain deny reason and exact remediation

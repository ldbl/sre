# Lab: Requests, Limits, QoS, and OOM Analysis

## Goal

Validate resource guardrails in `develop`:
- verify requests/limits are present
- verify namespace quota and default limits
- trigger controlled memory pressure and analyze behavior

## Prerequisites

- Flux healthy
- `develop` namespace workloads running

```bash
kubectl -n flux-system get kustomizations
kubectl -n develop get deploy backend frontend
```

## Step 1: Verify Namespace Controls

```bash
kubectl -n develop get limitrange
kubectl -n develop describe limitrange default-container-limits
kubectl -n develop get resourcequota
kubectl -n develop describe resourcequota compute-quota
```

Expected:
- both `LimitRange` and `ResourceQuota` exist
- defaults/min/max are visible

## Step 2: Verify Workload Resource Specs

```bash
kubectl -n develop get deploy backend -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
kubectl -n develop get deploy frontend -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

Expected:
- CPU/memory/ephemeral-storage requests and limits are set
- workloads are not BestEffort

## Step 3: Check QoS Class

```bash
kubectl -n develop get pod -l app=backend -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.qosClass}{"\n"}{end}'
kubectl -n develop get pod -l app=frontend -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.status.qosClass}{"\n"}{end}'
```

Expected:
- current workloads are typically `Burstable` (requests != limits)

## Step 4: Controlled OOM Drill (Test Pod)

```bash
kubectl -n develop run oom-demo \
  --image=busybox:1.36 \
  --restart=Never \
  --requests='cpu=50m,memory=64Mi' \
  --limits='cpu=100m,memory=64Mi' \
  -- sh -c 'x=; while true; do x=$x$(head -c 1M </dev/zero); sleep 0.1; done'
```

Observe:

```bash
kubectl -n develop get pod oom-demo -w
kubectl -n develop describe pod oom-demo | rg -n "OOMKilled|Reason|Exit Code"
```

Expected:
- pod enters `OOMKilled` and restarts/fails as per policy

## Step 5: Cleanup

```bash
kubectl -n develop delete pod oom-demo --ignore-not-found=true
```

## Hard Stop Conditions

- removing requests/limits from app manifests
- broad quota increase without incident capacity review
- scaling decisions without checking real resource pressure signals

## Done When

- learner validates quota/limitrange enforcement
- learner shows QoS class and explains why it is that class
- learner demonstrates and explains one controlled OOM event

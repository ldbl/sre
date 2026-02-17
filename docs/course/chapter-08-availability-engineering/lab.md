# Lab: HPA + PDB + Node Drain Readiness

## Goal

Validate availability controls in `staging`:
- HPA exists and can scale within safe bounds
- PDB constrains voluntary disruptions
- drain simulation is evaluated through PDB/HPA signals first

## Prerequisites

- Metrics API available (`kubectl top` works)
- backend/frontend deployed in `staging`

```bash
kubectl -n staging get deploy backend frontend
kubectl -n staging get hpa,pdb
```

## Step 1: Verify Baseline

```bash
kubectl -n staging get deploy backend frontend -o wide
kubectl -n staging get hpa backend frontend
kubectl -n staging get pdb backend frontend
```

Expected:
- replicas baseline >= 2
- HPA min/max configured
- PDB present with non-zero disruption control

## Step 2: Observe HPA Signals

```bash
kubectl -n staging describe hpa backend
kubectl -n staging describe hpa frontend
```

Check:
- current metrics (cpu/memory)
- desired replicas decision
- conditions (`AbleToScale`, `ScalingActive`, `ScalingLimited`)

## Step 3: PDB Disruption Budget Check

```bash
kubectl -n staging describe pdb backend
kubectl -n staging describe pdb frontend
```

Check:
- `Allowed disruptions`
- current healthy pods vs desired

## Step 4: Drain Preflight (Simulation)

Before any real drain:
1. capture HPA state
2. capture PDB allowed disruptions
3. confirm at least one safe disruption is allowed per critical workload

Commands:

```bash
kubectl -n staging get hpa,pdb
kubectl -n staging get pods -l app=backend
kubectl -n staging get pods -l app=frontend
```

If `Allowed disruptions = 0` for critical service:
- stop drain plan
- adjust replicas / PDB / rollout timing first

## Step 5: Controlled Rollout Check

```bash
kubectl -n staging rollout status deploy/backend
kubectl -n staging rollout status deploy/frontend
```

Expected:
- rollout progresses without violating PDB constraints

## Hard Stop Conditions

- drain action with `Allowed disruptions = 0`
- HPA minReplicas < required availability baseline
- PDB removed/relaxed without change review

## Done When

- learner can show HPA and PDB state for both services
- learner can decide if drain is safe based on evidence
- learner can explain one scenario where HPA cannot compensate for bad PDB settings

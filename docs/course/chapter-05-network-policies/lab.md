# Lab: Default Deny and Controlled Traffic Allowlist

## Goal

Build namespace isolation in `develop`:
- deny all ingress/egress by default
- allow DNS egress
- allow ingress only from ingress controller namespace
- validate blocked and allowed traffic paths

## Prerequisites

- cluster CNI supports `NetworkPolicy`
- access to namespace `develop`
- ingress controller namespace identified (commonly `ingress-nginx`)

Quick checks:

```bash
kubectl get ns
kubectl api-resources | rg -i networkpolicies
kubectl -n flux-system get kustomization network-policies-develop network-policies-staging network-policies-production
```

Set namespace variables:

```bash
export TARGET_NS=develop
export INGRESS_NS=ingress-nginx
```

## Step 0: Verify GitOps-Applied Baseline Policies

```bash
kubectl -n $TARGET_NS get networkpolicy
```

Expected (from Flux baseline):
- `default-deny-all`
- `allow-dns-egress`
- `allow-frontend-egress-backend`
- `allow-backend-ingress`
- `allow-frontend-ingress`

## Step 1: Baseline Connectivity Snapshot

```bash
kubectl -n $TARGET_NS get pods,svc
kubectl -n $TARGET_NS run np-debug --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl -n $TARGET_NS exec np-debug -- nslookup kubernetes.default.svc.cluster.local
```

Expected:
- DNS lookup works before deny policy

## Step 2: Apply Default Deny

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: develop
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF
```

Validation:

```bash
kubectl -n $TARGET_NS get networkpolicy
kubectl -n $TARGET_NS exec np-debug -- nslookup kubernetes.default.svc.cluster.local
```

Expected:
- DNS now fails (egress blocked)

## Step 3: Allow DNS Egress Only

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: develop
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

Validation:

```bash
kubectl -n $TARGET_NS exec np-debug -- nslookup kubernetes.default.svc.cluster.local
```

Expected:
- DNS works again

## Step 4: Allow Ingress from Ingress Controller

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-from-controller
  namespace: ${TARGET_NS}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ${INGRESS_NS}
EOF
```

Validation:

```bash
kubectl -n $TARGET_NS get networkpolicy
```

Expected:
- traffic from ingress controller namespace is permitted
- non-allowed namespaces remain blocked

## Step 5: Blocked Traffic Debug Drill

1. Launch debug pod in another namespace (for example `staging`).
2. Attempt to reach service in `develop`.
3. Confirm request is blocked and document which policy enforces it.

Example:

```bash
kubectl -n staging run np-debug-staging --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl -n staging exec np-debug-staging -- wget -qO- --timeout=2 http://backend.develop.svc.cluster.local:8080/version
```

## Rollback

```bash
kubectl -n $TARGET_NS delete networkpolicy default-deny-all allow-dns-egress allow-ingress-from-controller
kubectl -n $TARGET_NS delete pod np-debug --ignore-not-found=true
kubectl -n staging delete pod np-debug-staging --ignore-not-found=true
```

## Hard Stop Conditions

- applying deny policy in wrong namespace/environment
- combining app rollout and network policy changes in one PR
- no rollback manifest/commands prepared

## Done When

- learner demonstrates `deny -> allow DNS -> allow ingress-controller` flow
- learner can reproduce and explain one blocked traffic case
- learner can rollback policies safely

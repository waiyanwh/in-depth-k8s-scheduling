# Module 02: Taints and Tolerations

Learn how Kubernetes uses **taints** to repel pods and **tolerations** to allow specific pods through.

## Concepts

| Taint Effect | Behavior |
|--------------|----------|
| `NoSchedule` | New pods won't schedule unless they tolerate the taint |
| `PreferNoSchedule` | Scheduler tries to avoid, but will place if necessary |
| `NoExecute` | Evicts existing pods AND prevents new scheduling |

## Exercises

### 1. Set Up the "Electric Fence"

Taint production nodes so regular pods can't schedule:

```bash
./taint-nodes.sh
```

### 2. The Blocked App

Deploy an app that tries to run on production nodes without permission:

```bash
kubectl apply -f standard-web-app.yaml
kubectl get pods -w  # Watch pods stay Pending
```

**Observe**: All 5 pods will be `Pending` - they're blocked by the taint!

### 3. The Allowed App

Deploy an app with the proper toleration:

```bash
kubectl apply -f security-monitor-app.yaml
kubectl get pods -w
```

**Observe**: All 5 pods schedule successfully - they have the "key"!

### 4. Maintenance Simulation (NoExecute)

See how `NoExecute` evicts running pods:

```bash
# First, deploy some pods to a standard node
kubectl apply -f ../01-affinity/data-processor-flexible.yaml

# Then simulate maintenance
./simulate-maintenance.sh
```

**Observe**: Pods are evicted immediately when the node is tainted.

## Expected Results

| Deployment | Status | Reason |
|------------|--------|--------|
| `web-app` | Pending | No toleration for `tier=secure:NoSchedule` |
| `sec-monitor` | Running | Has toleration |

## Cleanup

```bash
kubectl delete -f standard-web-app.yaml
kubectl delete -f security-monitor-app.yaml
kubectl taint node zone-a-node-5 outage=true:NoExecute-  # Remove maintenance taint
```

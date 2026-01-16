# Module 02: Taints and Tolerations

## What You'll Learn
- How nodes **repel** pods using taints
- How pods can **tolerate** taints to schedule anyway
- The three taint effects: `NoSchedule`, `PreferNoSchedule`, `NoExecute`
- How `NoExecute` triggers **pod eviction**

---

## The Problem

Node Affinity tells the scheduler where pods **want** to go. But what if you need:
- GPU nodes reserved for GPU workloads only?
- Production nodes that reject dev pods?
- The ability to **evict running pods** during maintenance?

**Taints and Tolerations** work in the opposite direction — nodes repel pods.

---

## Key Concepts

```
┌─────────────────────────────────────────────────────────────────┐
│                    TAINT & TOLERATION MODEL                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   NODE (has taint)               POD (has toleration)           │
│   ┌─────────────┐                ┌─────────────────┐            │
│   │   ⚡ TAINT   │  ◀─── repels ──│ No Toleration   │  ❌ Blocked│
│   │             │                └─────────────────┘            │
│   │ gpu=true    │                                                │
│   │ :NoSchedule │                ┌─────────────────┐            │
│   │             │  ◀── allowed ──│ ✓ Toleration    │  ✓ Allowed │
│   └─────────────┘                │ gpu=true        │            │
│                                  └─────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

**Think of it like**:
- **Taint** = Electric fence on the node
- **Toleration** = Key to pass through the fence

---

## Taint Effects

| Effect | New Pods | Running Pods |
|--------|----------|--------------|
| `NoSchedule` | Blocked (won't schedule) | Unaffected (keep running) |
| `PreferNoSchedule` | Soft block (try to avoid) | Unaffected |
| `NoExecute` | Blocked | **Evicted immediately!** |

---

## How Taints Work in the Scheduler

```
┌──────────────────────────────────────────────────────────────┐
│                    SCHEDULER FILTER PHASE                     │
├──────────────────────────────────────────────────────────────┤
│  Pod: web-app (no tolerations)                                │
│                                                               │
│  Node: gpu-node-0                                             │
│    Taints: gpu=true:NoSchedule                                │
│    Pod tolerates? NO → ❌ Filtered out                        │
│                                                               │
│  Node: zone-a-node-0                                          │
│    Taints: (none)                                             │
│    Pod tolerates? N/A → ✓ Pass                                │
│                                                               │
│  Result: Pod can only schedule on zone-a-node-0               │
└──────────────────────────────────────────────────────────────┘
```

---

## YAML Deep Dive

### Applying a Taint to a Node

```bash
# Syntax: kubectl taint node <node> <key>=<value>:<effect>
kubectl taint node prod-node-0 tier=secure:NoSchedule
```

This creates:
```yaml
spec:
  taints:
    - key: tier
      value: secure
      effect: NoSchedule
```

### Removing a Taint

```bash
# Add a minus sign at the end
kubectl taint node prod-node-0 tier=secure:NoSchedule-
```

---

### Pod WITHOUT Toleration (standard-web-app.yaml)

```yaml
spec:
  nodeSelector:
    env: production    # This pod WANTS production nodes
  # NO tolerations!    # But it CAN'T get past the taint
```

**Result**: Pod stays **Pending** forever. It wants `prod-node-*` but can't get past the taint.

---

### Pod WITH Toleration (security-monitor-app.yaml)

```yaml
spec:
  nodeSelector:
    env: production    # This pod WANTS production nodes
  tolerations:         # And it HAS the key to get in
    - key: tier
      operator: Equal
      value: secure
      effect: NoSchedule
```

**Result**: Pod schedules successfully on `prod-node-*`.

---

### Toleration Operators

| Operator | Meaning |
|----------|---------|
| `Equal` | Key and value must match exactly |
| `Exists` | Only key must exist (any value) |

```yaml
# Match specific value
tolerations:
  - key: tier
    operator: Equal
    value: secure
    effect: NoSchedule

# Match any value for this key
tolerations:
  - key: tier
    operator: Exists
    effect: NoSchedule

# Tolerate ALL taints (use carefully!)
tolerations:
  - operator: Exists
```

---

## NoExecute: The Eviction Effect

Unlike `NoSchedule`, the `NoExecute` effect:
1. Blocks new pods (like NoSchedule)
2. **Evicts running pods** that don't tolerate it

```
┌──────────────────────────────────────────────────────────────┐
│                    NoExecute EVICTION                         │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  BEFORE: Node has pods running                                │
│    ┌─────────────────────────────────────────┐               │
│    │ zone-a-node-5      [pod-a] [pod-b]      │               │
│    └─────────────────────────────────────────┘               │
│                                                               │
│  kubectl taint node zone-a-node-5 outage=true:NoExecute      │
│                                                               │
│  AFTER: Pods evicted immediately!                             │
│    ┌─────────────────────────────────────────┐               │
│    │ zone-a-node-5      (empty)       ⚡     │               │
│    └─────────────────────────────────────────┘               │
│                                                               │
│  Pods reschedule to other nodes                               │
└──────────────────────────────────────────────────────────────┘
```

### tolerationSeconds

With `NoExecute`, you can delay eviction:

```yaml
tolerations:
  - key: node.kubernetes.io/unreachable
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 300  # Stay for 5 minutes before evicting
```

---

## Lab Exercises

### Exercise 1: Apply the "Electric Fence"

```bash
./taint-nodes.sh
```

This taints `prod-node-*` with `tier=secure:NoSchedule`.

---

### Exercise 2: Deploy Blocked App

```bash
kubectl apply -f standard-web-app.yaml
```

**Watch the visualizer**: Pods stay in **PENDING QUEUE**. They want production nodes but can't get past the taint.

---

### Exercise 3: Deploy Allowed App

```bash
kubectl apply -f security-monitor-app.yaml
```

**Watch the visualizer**: `sec-monitor` pods schedule on `prod-node-*` (they have the toleration).

---

### Exercise 4: Simulate Maintenance (NoExecute)

```bash
./simulate-maintenance.sh
```

**Watch the visualizer**: 
1. Before: Pods are running on `zone-a-node-5`
2. After taint: Pods are **immediately evicted** and reschedule elsewhere

---

## Real-World Use Cases

| Use Case | Taint | Purpose |
|----------|-------|---------|
| GPU isolation | `gpu=true:NoSchedule` | Reserve GPU nodes for ML workloads |
| Production separation | `env=prod:NoSchedule` | Keep dev pods off production |
| Spot instances | `spot=true:PreferNoSchedule` | Prefer non-spot unless needed |
| Node maintenance | `maintenance=true:NoExecute` | Drain node for updates |
| Node failure | `node.kubernetes.io/unreachable:NoExecute` | System-applied when node goes down |

---

## Built-in Taints (Applied Automatically)

Kubernetes adds these taints automatically:

| Taint | When Applied |
|-------|--------------|
| `node.kubernetes.io/not-ready` | Node is not ready |
| `node.kubernetes.io/unreachable` | Node is unreachable |
| `node.kubernetes.io/memory-pressure` | Node has memory pressure |
| `node.kubernetes.io/disk-pressure` | Node has disk pressure |
| `node.kubernetes.io/pid-pressure` | Node has too many processes |
| `node.kubernetes.io/unschedulable` | Node marked unschedulable (cordon) |

---

## Cleanup

```bash
./cleanup.sh
# This removes deployments AND clears taints
```

---

## Key Takeaways

1. **Taints** are on nodes — they repel pods
2. **Tolerations** are on pods — they allow scheduling past taints
3. `NoSchedule` blocks new pods but doesn't affect running pods
4. `NoExecute` evicts running pods immediately
5. Use `tolerationSeconds` to delay NoExecute eviction
6. Taints + Tolerations work **together** with affinity, not instead of

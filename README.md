# In-Depth Kubernetes Scheduling 🥋

A hands-on lab for mastering **Kubernetes scheduling concepts** using KWOK (Kubernetes WithOut Kubelet).

## What is Kubernetes Scheduling?

In Kubernetes, **scheduling** is the process of matching Pods to Nodes so the kubelet can run them. The **kube-scheduler** watches for newly created Pods that have no Node assigned, and selects the best Node for each Pod.

```
┌─────────────────────────────────────────────────────────────────┐
│                     SCHEDULING PIPELINE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. WATCH          2. FILTER           3. SCORE        4. BIND │
│   ┌─────┐          ┌─────────┐         ┌───────┐       ┌──────┐ │
│   │ Pod │ ───────▶ │ Remove  │ ──────▶ │ Rank  │ ────▶ │ Bind │ │
│   │Queue│          │ Invalid │         │ Valid │       │to API│ │
│   └─────┘          │ Nodes   │         │ Nodes │       └──────┘ │
│                    └─────────┘         └───────┘                │
│                                                                 │
│   Pending pods     Nodes that can't    Best node         Pod is │
│   waiting to be    run the pod are     gets highest      bound  │
│   scheduled        eliminated          score             to node│
└─────────────────────────────────────────────────────────────────┘
```

### Key Concepts

| Concept | Description | Lab Module |
|---------|-------------|------------|
| **Node Affinity** | Pod expresses preference for certain nodes | Module 01 |
| **Taints & Tolerations** | Nodes repel pods unless they tolerate the taint | Module 02 |
| **Topology Spread** | Distribute pods evenly across failure domains | Module 03 |
| **Priority & Preemption** | Higher priority pods can evict lower priority ones | Module 04 |
| **Manual Scheduling** | Bypass scheduler by setting `nodeName` directly | Module 05 |

---

## Prerequisites

- [kwokctl](https://kwok.sigs.k8s.io/docs/user/installation/) — KWOK cluster manager
- [kubectl](https://kubernetes.io/docs/tasks/tools/) — Kubernetes CLI
- Python 3 — For node generation script

---

## Quick Start

```bash
cd 00-setup
./setup-cluster.sh
```

This creates a KWOK cluster with **30 simulated nodes**:

| Nodes | Name Pattern | Labels | Purpose |
|-------|--------------|--------|---------|
| 10 | `zone-a-node-*` | `zone=us-east-1a` | Standard nodes in Zone A |
| 10 | `zone-b-node-*` | `zone=us-east-1b` | Standard nodes in Zone B |
| 5 | `gpu-node-*` | `type=gpu` + taint | GPU nodes (tainted) |
| 5 | `prod-node-*` | `env=production` | Production nodes |

---

## Learning Path

### Module 01: Node Affinity
**Question**: *How do I tell the scheduler WHERE I want my pods to run?*

Learn the difference between:
- `nodeSelector` — Simple key-value matching
- `requiredDuringScheduling...` — Hard requirement (must match)
- `preferredDuringScheduling...` — Soft preference (try to match)

→ [Start Module 01](./01-affinity/README.md)

---

### Module 02: Taints and Tolerations
**Question**: *How do I PREVENT certain pods from running on certain nodes?*

Learn how:
- **Taints** on nodes repel pods (like an electric fence)
- **Tolerations** on pods allow them through (like a key)
- **NoExecute** effect evicts running pods immediately

→ [Start Module 02](./02-taints/README.md)

---

### Module 03: Topology Spread Constraints
**Question**: *How do I ensure my pods are EVENLY distributed across zones?*

Learn how:
- `topologySpreadConstraints` enforce balanced placement
- `maxSkew` controls maximum imbalance allowed
- `whenUnsatisfiable` determines hard vs soft enforcement

→ [Start Module 03](./03-topology/README.md)

---

### Module 04: Priority and Preemption
**Question**: *What happens when the cluster is FULL but a critical pod needs to run?*

Learn how:
- `PriorityClass` defines pod importance (higher value = more important)
- **Preemption** evicts lower-priority pods to make room
- `preemptionPolicy: Never` prevents a pod from evicting others

→ [Start Module 04](./04-preemption/README.md)

---

### Module 05: Manual Scheduling
**Question**: *How does the scheduler actually BIND pods to nodes?*

Learn how:
- `schedulerName` lets you use custom schedulers
- `spec.nodeName` bypasses the scheduler entirely
- The **Binding API** is what schedulers use internally

→ [Start Module 05](./05-manual-scheduling/README.md)

---

## Scheduling Quick Reference

### Pod Spec Fields That Affect Scheduling

```yaml
spec:
  # Simple node selection
  nodeSelector:
    key: value
  
  # Advanced node selection
  affinity:
    nodeAffinity: { ... }
    podAffinity: { ... }
    podAntiAffinity: { ... }
  
  # Tolerate node taints
  tolerations:
    - key: "key"
      operator: "Equal"
      value: "value"
      effect: "NoSchedule"
  
  # Spread across topology
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
  
  # Pod importance
  priorityClassName: high-priority
  
  # Bypass scheduler
  nodeName: specific-node
  schedulerName: my-custom-scheduler
```

---

## Cleanup

```bash
kwokctl delete cluster --name scheduling-lab
```

---

## Project Structure

```
in-depth-k8s-scheduling/
├── 00-setup/                    # Cluster setup scripts
├── 01-affinity/                 # Node affinity lab
├── 02-taints/                   # Taints & tolerations lab
├── 03-topology/                 # Topology spread lab
├── 04-preemption/               # Priority & preemption lab
├── 05-manual-scheduling/        # Manual scheduling lab
├── tools/                       # Visualization tools
└── README.md                    # This file
```

---

## Further Reading

- [Kubernetes Scheduler](https://kubernetes.io/docs/concepts/scheduling-eviction/kube-scheduler/)
- [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)
- [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)

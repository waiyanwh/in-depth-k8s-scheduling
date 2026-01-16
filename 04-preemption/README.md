# Module 04: Priority and Preemption

## What You'll Learn
- How to define **pod importance** using PriorityClass
- How **preemption** evicts lower-priority pods
- The `preemptionPolicy` options
- When and why preemption happens

---

## The Problem

Your cluster is at full capacity. A critical pod (payment processing) needs to run, but all nodes are occupied by batch jobs. What happens?

Without priority: The critical pod waits in queue. Customers can't pay. Revenue lost.

With priority: The critical pod **preempts** (evicts) batch jobs and runs immediately.

---

## Key Concepts

```
┌─────────────────────────────────────────────────────────────────┐
│                    PREEMPTION SCENARIO                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  BEFORE: Cluster is full of low-priority batch jobs             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ gpu-node-0: [batch] [batch]                                 ││
│  │ gpu-node-1: [batch] [batch]                                 ││
│  │ gpu-node-2: [batch] [batch]                                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  NEW: High-priority "payment" pod arrives                       │
│  ┌────────────────────────────┐                                 │
│  │ priorityClassName: high    │                                 │
│  └────────────────────────────┘                                 │
│                                                                 │
│  AFTER: Batch pod evicted, payment pod scheduled                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ gpu-node-0: [PAYMENT] [batch]    ← VIP takes the spot       ││
│  │ gpu-node-1: [batch] [batch]                                 ││
│  │ gpu-node-2: [batch] [batch]                                 ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## How Priority Works

### Priority Value

Every pod has a priority value (integer). Higher value = more important.

| Value Range | Typical Use |
|-------------|-------------|
| 1,000,000+ | Critical system components |
| 100,000 | Business-critical services |
| 10,000 | Standard applications |
| 1,000 | Batch jobs, optional workloads |
| 0 | Lowest priority (default) |

---

### PriorityClass Resource

Define priority levels cluster-wide:

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000              # The actual priority number
globalDefault: false        # If true, applies to all pods without priorityClassName
preemptionPolicy: PreemptLowerPriority  # Can this priority preempt others?
description: "Critical workloads that can preempt batch jobs"
```

---

## preemptionPolicy Options

| Policy | Behavior |
|--------|----------|
| `PreemptLowerPriority` | Can evict lower-priority pods (default) |
| `Never` | Cannot evict any pods, even if higher priority |

**Use `Never` when**: You want priority for queue ordering but don't want to disrupt running workloads.

---

## How Preemption Works

┌──────────────────────────────────────────────────────────────┐
│                    PREEMPTION PROCESS                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. TRIGGER                                                  │
│     High-priority pod can't be scheduled (no space)          │
│                                                              │
│  2. FIND VICTIMS                                             │
│     Scheduler looks for nodes where evicting low-priority    │
│     pods would make room for the high-priority pod           │
│                                                              │
│  3. SELECT NODE                                              │
│     Choose node that requires fewest/lowest evictions        │
│                                                              │
│  4. EVICT                                                    │
│     Delete victim pods (graceful termination applies)        │
│                                                              │
│  5. WAIT                                                     │
│     Wait for victims to terminate                            │
│                                                              │
│  6. SCHEDULE                                                 │
│     Place high-priority pod on the freed node                │
└──────────────────────────────────────────────────────────────┘
```

---

## YAML Deep Dive

### Priority Classes (priorities.yaml)

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 1000                           # Low value = less important
preemptionPolicy: PreemptLowerPriority
description: "Batch jobs that can be preempted"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000                        # High value = very important
preemptionPolicy: PreemptLowerPriority
description: "Critical services that can preempt others"
```

---

### Low-Priority Pod (low-prio-fillers.yaml)

```yaml
spec:
  priorityClassName: low-priority     # Use the low priority class
  nodeSelector:
    type: gpu                         # Target GPU nodes
  tolerations:
    - key: gpu
      operator: Equal
      value: "true"
      effect: NoSchedule
```

---

### High-Priority Pod (high-prio-vip.yaml)

```yaml
spec:
  priorityClassName: high-priority    # Use the high priority class
  nodeSelector:
    type: gpu                         # Same target nodes
  tolerations:
    - key: gpu
      operator: Equal
      value: "true"
      effect: NoSchedule
```

---

## Lab Exercises

### Exercise 1: Create Priority Classes

```bash
kubectl apply -f priorities.yaml
```

Verify:
```bash
kubectl get priorityclasses
```

---

### Exercise 2: Flood GPU Nodes with Low-Priority

```bash
kubectl apply -f low-prio-fillers.yaml
```

**Watch the visualizer**: 50 batch-processing pods try to schedule. GPU nodes fill up, rest go to Pending queue.

---

### Exercise 3: Deploy VIP Pods (Trigger Preemption!)

```bash
kubectl apply -f high-prio-vip.yaml
```

**Watch the visualizer**:
1. `realtime-analytics` pods appear (high-priority)
2. Some `batch-processing` pods **disappear** (evicted!)
3. VIP pods take their spots on GPU nodes

---

### Exercise 4: Monitor the Battle

```bash
./watch-battle.sh
```

Shows real-time counts and preemption events.

---

## Graceful Termination

When a pod is preempted:
1. Pod receives SIGTERM
2. Pod has `terminationGracePeriodSeconds` to shut down (default 30s)
3. After grace period, SIGKILL is sent
4. Pod is deleted

**Important**: Preemption respects PodDisruptionBudgets!

---

## Real-World Use Cases

| Use Case | Priority Level | preemptionPolicy |
|----------|----------------|------------------|
| Payment processing | High (1M+) | PreemptLowerPriority |
| User-facing APIs | Medium (100K) | PreemptLowerPriority |
| Background sync | Low (10K) | Never |
| Batch ML training | Very low (1K) | Never |
| Spot instance workloads | Lowest (100) | Never |

---

## Scheduling Queue Order

Even without preemption, priority affects queue ordering:

```
┌──────────────────────────────────────────────────────────────┐
│                    SCHEDULING QUEUE                          │
├──────────────────────────────────────────────────────────────┤
│  Priority 1000000: [payment-pod]        ← Scheduled first    │
│  Priority 100000:  [api-pod-1] [api-pod-2]                   │
│  Priority 1000:    [batch-1] [batch-2] [batch-3]             │
│  Priority 0:       [optional-job]       ← Scheduled last     │
└──────────────────────────────────────────────────────────────┘
```

---

## Built-in Priority Classes

Kubernetes has two built-in classes:

| Class | Value | Purpose |
|-------|-------|---------|
| `system-cluster-critical` | 2000000000 | Critical cluster components (scheduler, controller-manager) |
| `system-node-critical` | 2000001000 | Critical node components (kube-proxy, kubelet) |

**Never set your pods higher than these!**

---

## Cleanup

```bash
./cleanup.sh
# Or manually:
kubectl delete -f high-prio-vip.yaml
kubectl delete -f low-prio-fillers.yaml
kubectl delete -f priorities.yaml
```

---

## Key Takeaways

1. **PriorityClass** defines pod importance (higher value = more important)
2. **Preemption** evicts lower-priority pods to make room for higher-priority ones
3. Use `preemptionPolicy: Never` for priority without disruption
4. Priority affects **queue order** even without preemption
5. Preemption respects **graceful termination** and **PodDisruptionBudgets**
6. **Never exceed system-cluster-critical** priority for user workloads

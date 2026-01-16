# Module 04: Pod Priority and Preemption

Learn how Kubernetes uses **priority classes** to determine which pods can preempt others when resources are scarce.

## Concepts

| Term | Description |
|------|-------------|
| **PriorityClass** | Defines a priority value (higher = more important) |
| **Preemption** | Evicting lower-priority pods to make room for higher-priority ones |
| **preemptionPolicy** | Controls whether a priority class can preempt (`PreemptLowerPriority` or `Never`) |

## Setup

### 1. Apply Priority Classes

```bash
kubectl apply -f priorities.yaml
```

This creates:
- `low-priority` (value: 1,000)
- `high-priority` (value: 1,000,000)

## Exercises

### 2. Flood GPU Nodes with Low-Priority Pods

```bash
kubectl apply -f low-prio-fillers.yaml
kubectl get pods -w  # Wait for pods to fill GPU nodes
```

**Observe**: 50 pods targeting only 5 GPU nodes. Many will be Pending.

### 3. Deploy VIP Pods (Trigger Preemption!)

```bash
# Start the battle watcher in one terminal
./watch-battle.sh

# In another terminal, deploy VIP pods
kubectl apply -f high-prio-vip.yaml
```

**Observe**: VIP pods preempt batch pods to get scheduled!

### 4. Watch the Battle

```bash
./watch-battle.sh
```

Shows real-time:
- Running/Pending counts by priority
- Progress bars
- Preemption events

## Expected Results

| Before VIP Deploy | After VIP Deploy |
|-------------------|------------------|
| 50 batch pods competing for GPU | 5 VIP pods all Running |
| Some batch Pending | Some batch preempted |
| No preemption events | Preemption events logged |

## How Preemption Works

1. Scheduler sees high-priority pod can't fit
2. Finds victim pods with lower priority
3. Evicts victims (marks for deletion)
4. Waits for victims to terminate
5. Schedules high-priority pod

## Cleanup

```bash
kubectl delete -f high-prio-vip.yaml
kubectl delete -f low-prio-fillers.yaml
kubectl delete -f priorities.yaml
```

# Module 01: Node Affinity

Learn how Kubernetes schedules pods based on node labels using **Node Affinity**.

## Concepts

| Type | Behavior |
|------|----------|
| `requiredDuringSchedulingIgnoredDuringExecution` | **Hard requirement** - pod won't schedule if no matching node exists |
| `preferredDuringSchedulingIgnoredDuringExecution` | **Soft preference** - scheduler tries to match but falls back if needed |

## Exercises

### 1. Strict GPU Affinity

Deploy workloads that **must** run on GPU nodes:

```bash
kubectl apply -f gpu-strict.yaml
```

**Observe**: All 5 pods should land on `node-21` to `node-25` (the GPU nodes).

### 2. Flexible GPU Preference

Deploy workloads that **prefer** GPU nodes but can run elsewhere:

```bash
kubectl apply -f data-processor-flexible.yaml
```

**Observe**: With 15 replicas but only 5 GPU nodes, some pods will "spill over" to standard nodes.

### 3. Watch the Distribution

```bash
./watch-distribution.sh
```

This script updates every 2 seconds showing:
- How many pods are on GPU vs Standard nodes
- Breakdown by deployment
- Pod status details

## Expected Results

After deploying both workloads:

| Deployment | Replicas | Expected Location |
|------------|----------|-------------------|
| `ai-model-training` | 5 | All on GPU nodes (strict) |
| `data-processor` | 15 | ~5 on GPU, ~10 on standard (flexible) |

## Cleanup

```bash
kubectl delete -f gpu-strict.yaml
kubectl delete -f data-processor-flexible.yaml
```

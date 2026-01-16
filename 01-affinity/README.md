# Module 01: Node Affinity

## What You'll Learn
- How pods express **preferences** for certain nodes
- Difference between **required** (hard) and **preferred** (soft) affinity
- How the scheduler **filters** and **scores** nodes based on affinity rules

---

## The Problem

By default, the scheduler places pods on any available node. But what if you need:
- GPU workloads to run **only** on GPU nodes?
- Data processing jobs to **prefer** nodes with NVMe storage?
- Pods to run in a **specific availability zone**?

**Node Affinity** solves this by letting pods declare which nodes they want.

---

## Key Concepts

### nodeSelector (Simple)

The simplest form of node selection — a key-value match:

```yaml
spec:
  nodeSelector:
    type: gpu  # Must match exactly
```

**Limitation**: Only supports equality. No "OR" logic, no preferences.

---

### Node Affinity (Advanced)

More powerful than `nodeSelector` with two modes:

| Mode | Meaning | If No Match |
|------|---------|-------------|
| `requiredDuringSchedulingIgnoredDuringExecution` | **Must** match | Pod stays Pending |
| `preferredDuringSchedulingIgnoredDuringExecution` | **Try** to match | Pod schedules elsewhere |

---

## How the Scheduler Uses Affinity

```
┌──────────────────────────────────────────────────────────────┐
│                    SCHEDULER DECISION                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  1. FILTER PHASE (required affinity)                         │
│     ┌─────────────────────────────────────────────────────┐  │
│     │ Node A (type=gpu)     ✓ Pass                        │  │
│     │ Node B (type=gpu)     ✓ Pass                        │  │
│     │ Node C (type=standard) ✗ Filtered Out               │  │
│     └─────────────────────────────────────────────────────┘  │
│                                                              │
│  2. SCORE PHASE (preferred affinity)                         │
│     ┌─────────────────────────────────────────────────────┐  │
│     │ Node A: +100 points (has accelerator=nvidia)        │  │
│     │ Node B: +0 points (no accelerator label)            │  │
│     └─────────────────────────────────────────────────────┘  │
│                                                              │
│  3. WINNER: Node A (highest score)                           │
└──────────────────────────────────────────────────────────────┘
```

---

## YAML Deep Dive

### Required Affinity (gpu-strict.yaml)

```yaml
spec:
  affinity:
    nodeAffinity:
      # HARD REQUIREMENT - Pod CANNOT schedule without this
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: type           # Node label key
                operator: In        # Must be IN the list
                values:
                  - gpu             # Allowed values
```

**Operators available**:
| Operator | Meaning |
|----------|---------|
| `In` | Label value is in the list |
| `NotIn` | Label value is NOT in the list |
| `Exists` | Label key exists (any value) |
| `DoesNotExist` | Label key does not exist |
| `Gt` | Label value is greater than |
| `Lt` | Label value is less than |

---

### Preferred Affinity (data-processor-flexible.yaml)

```yaml
spec:
  affinity:
    nodeAffinity:
      # SOFT PREFERENCE - Try to match, but don't fail if you can't
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100          # Higher weight = stronger preference
          preference:
            matchExpressions:
              - key: type
                operator: In
                values:
                  - gpu
```

**Weight**: 1-100. When multiple preferences exist, they're scored and summed.

---

## Lab Exercises

### Exercise 1: Strict GPU Placement

```bash
kubectl apply -f gpu-strict.yaml
```

**Watch the visualizer**: All 5 `ai-model-training` pods land on `gpu-node-*` only.

**Why?** The `required` affinity filters out all non-GPU nodes.

---

### Exercise 2: Flexible with Spillover

```bash
kubectl apply -f data-processor-flexible.yaml
```

**Watch the visualizer**: 
- First pods fill GPU nodes (they're preferred)
- Remaining pods spill to `zone-a-*` and `zone-b-*` nodes

**Why?** The `preferred` affinity scores GPU nodes higher, but when they're full, other nodes are acceptable.

---

### Exercise 3: Watch the Distribution

```bash
./watch-distribution.sh
```

See real-time pod counts on GPU vs Standard nodes.

---

## Real-World Use Cases

| Use Case | Affinity Type | Example |
|----------|---------------|---------|
| GPU workloads | Required | Must run on nodes with `accelerator=nvidia` |
| SSD preference | Preferred | Prefer nodes with `storage=nvme`, but OK without |
| Zone restrictions | Required | Must stay in `zone=us-east-1a` for latency |
| Cost optimization | Preferred | Prefer spot instances but accept on-demand |

---

## Inter-Pod Affinity (Not Demoed)

Pods can also express affinity/anti-affinity toward **other pods**:

```yaml
affinity:
  podAffinity:        # Schedule NEAR pods with label X
  podAntiAffinity:    # Schedule AWAY from pods with label X
```

Use case: Co-locate web servers with their cache. Spread replicas across nodes.

---

## Cleanup

```bash
./cleanup.sh
# Or manually:
kubectl delete -f gpu-strict.yaml
kubectl delete -f data-processor-flexible.yaml
```

---

## Key Takeaways

1. **nodeSelector** is simple but limited (equality only)
2. **Required** affinity is a hard filter — no match = Pending forever
3. **Preferred** affinity is a soft score — no match = try other nodes
4. Use **weight** to prioritize multiple preferences
5. The scheduler **filters first**, then **scores** remaining nodes

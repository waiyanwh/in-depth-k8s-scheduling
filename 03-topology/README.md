# Module 03: Topology Spread Constraints

## What You'll Learn
- How to **distribute pods evenly** across failure domains
- Understanding `topologyKey`, `maxSkew`, and `whenUnsatisfiable`
- Difference between **hard** and **soft** spread enforcement
- Why this matters for **high availability**

---

## The Problem

Your application has 10 replicas. Without any constraints, the scheduler might place all 10 on a single node or zone. If that zone fails, your entire application goes down.

**Topology Spread Constraints** ensure pods are distributed across failure domains (zones, nodes, racks).

---

## Key Concepts

```
┌─────────────────────────────────────────────────────────────────┐
│                    WITHOUT TOPOLOGY SPREAD                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Zone A                          Zone B                         │
│  ┌─────────────────┐            ┌─────────────────┐             │
│  │ [pod] [pod]     │            │                 │             │
│  │ [pod] [pod]     │            │ (empty!)        │             │
│  │ [pod] [pod]     │            │                 │             │
│  │ [pod] [pod]     │            │                 │             │
│  │ [pod] [pod]     │            │                 │             │
│  └─────────────────┘            └─────────────────┘             │
│                                                                 │
│  ❌ If Zone A fails, ALL pods are lost!                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    WITH TOPOLOGY SPREAD                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Zone A                          Zone B                         │
│  ┌─────────────────┐            ┌─────────────────┐             │
│  │ [pod] [pod]     │            │ [pod] [pod]     │             │
│  │ [pod] [pod]     │            │ [pod] [pod]     │             │
│  │ [pod]           │            │ [pod]           │             │
│  └─────────────────┘            └─────────────────┘             │
│                                                                 │
│  ✓ If Zone A fails, Zone B still has 5 pods running!            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Topology Spread Fields

| Field | Description |
|-------|-------------|
| `topologyKey` | Node label to spread across (zone, hostname, rack) |
| `maxSkew` | Maximum allowed difference between domains |
| `whenUnsatisfiable` | What to do if constraint can't be met |
| `labelSelector` | Which pods to count for the spread |
| `minDomains` | Minimum number of domains required |

---

## How maxSkew Works

```
maxSkew = 1 means: the difference between any two zones ≤ 1

┌────────────────────────────────────────────────────────────┐
│  Example: 10 pods, 2 zones, maxSkew=1                      │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Zone A: 5 pods                                            │
│  Zone B: 5 pods                                            │
│  Difference = 0  ✓ (0 ≤ maxSkew of 1)                      │
│                                                            │
│  Zone A: 6 pods                                            │
│  Zone B: 5 pods                                            │
│  Difference = 1  ✓ (1 ≤ maxSkew of 1)                      │
│                                                            │
│  Zone A: 7 pods                                            │
│  Zone B: 5 pods                                            │
│  Difference = 2  ❌ (2 > maxSkew of 1) → Blocked!          │
└────────────────────────────────────────────────────────────┘
```

---

## whenUnsatisfiable Options

| Value | Behavior |
|-------|----------|
| `DoNotSchedule` | **Hard constraint** — Pod stays Pending if can't satisfy |
| `ScheduleAnyway` | **Soft constraint** — Schedule anyway, just try to minimize skew |

---

## YAML Deep Dive

### Zone-Aware App (zone-aware-app.yaml)

```yaml
spec:
  topologySpreadConstraints:
    - maxSkew: 1                              # Max difference of 1 between zones
      topologyKey: topology.kubernetes.io/zone # Spread across zones
      whenUnsatisfiable: DoNotSchedule        # Hard requirement
      labelSelector:
        matchLabels:
          app: payment-gateway                # Count pods with this label
```

**What happens**:
1. Scheduler counts `payment-gateway` pods in each zone
2. When placing a new pod, it calculates which zone has the fewest
3. If placing in any zone would exceed `maxSkew`, pod stays Pending
4. Otherwise, places in the zone with fewest pods

---

### Multiple Constraints

You can combine spread across zones AND nodes:

```yaml
spec:
  topologySpreadConstraints:
    # First: spread across zones
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: web
    # Second: spread across nodes within each zone
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway  # Soft for node-level
      labelSelector:
        matchLabels:
          app: web
```

---

## Common topologyKey Values

| topologyKey | Spreads Across |
|-------------|----------------|
| `topology.kubernetes.io/zone` | Availability zones |
| `topology.kubernetes.io/region` | Cloud regions |
| `kubernetes.io/hostname` | Individual nodes |
| `rack` (custom) | Server racks |
| `building` (custom) | Physical buildings |

---

## Lab Exercises

### Exercise 1: Deploy Zone-Aware App

```bash
kubectl apply -f zone-aware-app.yaml
```

**Watch the visualizer**: 
- 10 pods in Zone A (`zone-a-node-*`)
- 10 pods in Zone B (`zone-b-node-*`)
- Perfect 50/50 split!

---

### Exercise 2: Verify Distribution

```bash
./verify-zones.sh
```

Output shows pod count per zone and calculates skew.

**Expected**:
```
payment-gateway:
    us-east-1a:          10 pods
    us-east-1b:          10 pods
    ✓ Skew: 0 (balanced)
```

---

### Exercise 3: Compare with Clumped App

```bash
kubectl apply -f clumped-app.yaml
```

This deployment has NO topology constraints. Distribution is not guaranteed.

---

## Scheduler Decision Process

```
┌──────────────────────────────────────────────────────────────┐
│                    SCHEDULING new-pod                        │
├──────────────────────────────────────────────────────────────┤
│  Current state:                                              │
│    Zone A: 5 payment-gateway pods                            │
│    Zone B: 4 payment-gateway pods                            │
│                                                              │
│  If we place in Zone A:                                      │
│    Zone A: 6, Zone B: 4 → Skew = 2 ❌ (exceeds maxSkew=1)    │
│                                                              │
│  If we place in Zone B:                                      │
│    Zone A: 5, Zone B: 5 → Skew = 0 ✓ (within maxSkew=1)      │
│                                                              │
│  Result: Scheduler chooses Zone B                            │
└──────────────────────────────────────────────────────────────┘
```

---

## Real-World Use Cases

| Use Case | Configuration |
|----------|---------------|
| Multi-zone HA | Spread across `topology.kubernetes.io/zone` |
| Rack awareness | Spread across custom `rack` label |
| Node distribution | Spread across `kubernetes.io/hostname` |
| Stateless services | `maxSkew: 1` + `DoNotSchedule` |
| Best-effort spread | `maxSkew: 2` + `ScheduleAnyway` |

---

## Interaction with Other Scheduling

Topology Spread works **together** with:
- **Node Affinity**: First filter nodes, then spread across them
- **Taints/Tolerations**: Only spread across toleratable nodes
- **Resource Requests**: Only spread across nodes with capacity

Order of evaluation:
1. Filter by taints/tolerations
2. Filter by node affinity
3. Filter by resource availability
4. **Apply topology spread constraints**
5. Score and select best node

---

## Cleanup

```bash
./cleanup.sh
# Or manually:
kubectl delete -f zone-aware-app.yaml
kubectl delete -f clumped-app.yaml
```

---

## Key Takeaways

1. **topologyKey** defines what to spread across (zone, node, rack)
2. **maxSkew** is the maximum imbalance allowed between domains
3. **DoNotSchedule** = hard requirement (pod may stay Pending)
4. **ScheduleAnyway** = soft preference (spread but don't block)
5. Combine zone spread + node spread for maximum HA
6. Use `labelSelector` to control which pods count toward the spread

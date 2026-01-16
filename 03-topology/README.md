# Module 03: Topology Spread Constraints

Learn how to distribute pods evenly across failure domains (zones, nodes, racks).

## Concepts

| Field | Description |
|-------|-------------|
| `maxSkew` | Maximum allowed difference in pod count between topology domains |
| `topologyKey` | Node label to group by (e.g., `topology.kubernetes.io/zone`) |
| `whenUnsatisfiable` | `DoNotSchedule` (strict) or `ScheduleAnyway` (soft) |

## Exercises

### 1. Zone-Aware Deployment

Deploy an app that spreads evenly across zones:

```bash
kubectl apply -f zone-aware-app.yaml
./verify-zones.sh
```

**Expected Result**: 10 pods in `us-east-1a`, 10 pods in `us-east-1b` (skew ≤ 1).

### 2. Legacy/Clumped Deployment

Deploy an app without topology constraints:

```bash
kubectl apply -f clumped-app.yaml
./verify-zones.sh
```

**Expected Result**: Distribution may vary. In this KWOK cluster it might balance, but in real clusters with uneven resources, pods could cluster in one zone.

### 3. Compare the Results

Run the zone verifier to see the difference:

```bash
./verify-zones.sh
```

Look for:
- `payment-gateway`: Skew should be 0 or 1 ✓
- `legacy-cache`: Skew may be higher ✗

## Why This Matters

| Scenario | With Constraints | Without Constraints |
|----------|-----------------|---------------------|
| Zone A fails | 50% of pods survive | 0-100% survive (random) |
| Zone B overloaded | Traffic balanced | Potential cascade failure |

## Cleanup

```bash
kubectl delete -f zone-aware-app.yaml
kubectl delete -f clumped-app.yaml
```

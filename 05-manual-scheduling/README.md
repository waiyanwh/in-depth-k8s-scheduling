# Module 05: Manual Scheduling

Learn how to bypass the Kubernetes scheduler by manually binding pods to nodes.

## Concepts

| Field | Description |
|-------|-------------|
| `schedulerName` | Which scheduler handles this pod (default: `default-scheduler`) |
| `spec.nodeName` | Directly assigns pod to a node, bypassing scheduler |

## How It Works

1. When a pod has no `nodeName`, it goes to the scheduler queue
2. If `schedulerName` doesn't match any running scheduler, pod is ignored
3. Setting `nodeName` directly binds the pod - no scheduler needed!

## Exercises

### 1. Create the "Ghost" Pod

```bash
kubectl apply -f ghost-app.yaml
kubectl get pods -w
```

**Observe**: Pod stays `Pending` forever - `ghost-scheduler` doesn't exist!

```bash
kubectl describe pod mystery-pod | grep -A3 Events
```

You'll see no scheduling events because no scheduler is handling it.

### 2. Be the Scheduler!

```bash
./be-the-scheduler.sh node-01
```

Or specify a different node:
```bash
./be-the-scheduler.sh node-15
```

**Observe**: Pod immediately becomes `Running`!

### 3. Understand What Happened

```bash
kubectl get pod mystery-pod -o yaml | grep nodeName
```

You manually set `nodeName`, which is exactly what the scheduler does internally.

## Real-World Use Cases

| Use Case | Example |
|----------|---------|
| Custom Schedulers | GPU-aware scheduler, data-locality scheduler |
| Scheduler Extenders | Webhook-based scheduling decisions |
| Static Pods | Kubelet-managed pods on specific nodes |
| Testing | Force pod placement for debugging |

## Cleanup

```bash
kubectl delete -f ghost-app.yaml
```

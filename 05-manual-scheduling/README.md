# Module 05: Manual Scheduling

## What You'll Learn
- How the **kube-scheduler** actually works internally
- The difference between `schedulerName` and `nodeName`
- How to **bypass the scheduler** entirely
- When and why you'd use **custom schedulers**

---

## The Problem

The default scheduler is great for most workloads. But what if:
- You need a specialized scheduler for GPU bin-packing?
- You want to test what happens when the scheduler is unavailable?
- You need a pod to run on an exact node immediately?

Understanding how the scheduler works helps you know when to bypass it.

---

## How the Kubernetes Scheduler Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    kube-scheduler INTERNALS                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. WATCH                                                       │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ API Server: "New pod created, nodeName is empty!"      │  │
│     └────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  2. FILTER (Predicates)                                         │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ Remove nodes that CAN'T run the pod:                   │  │
│     │ - Insufficient resources                               │  │
│     │ - Taints not tolerated                                 │  │
│     │ - Node affinity not matched                            │  │
│     │ - Port conflicts                                       │  │
│     └────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  3. SCORE (Priorities)                                          │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ Rank remaining nodes by preference:                    │  │
│     │ - Preferred affinity                                   │  │
│     │ - Resource balance                                     │  │
│     │ - Topology spread                                      │  │
│     │ - Image locality                                       │  │
│     └────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  4. BIND                                                        │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ Create a Binding object:                               │  │
│     │   pod.spec.nodeName = "selected-node"                  │  │
│     └────────────────────────────────────────────────────────┘  │
│                          ↓                                      │
│  5. KUBELET                                                     │
│     ┌────────────────────────────────────────────────────────┐  │
│     │ Kubelet on selected node sees the pod and runs it      │  │
│     └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Fields

### schedulerName

Tell Kubernetes which scheduler should handle this pod:

```yaml
spec:
  schedulerName: my-custom-scheduler  # Default is "default-scheduler"
```

If the specified scheduler doesn't exist, the pod stays **Pending forever**.

---

### nodeName

Skip the scheduler entirely — directly assign the pod:

```yaml
spec:
  nodeName: zone-a-node-0  # Pod goes directly to this node
```

**Warning**: This bypasses ALL scheduling logic:
- No resource checking
- No affinity checking
- No taint checking

---

## The Binding API

When a scheduler decides where a pod should go, it creates a `Binding` object:

```yaml
apiVersion: v1
kind: Binding
metadata:
  name: my-pod
  namespace: default
target:
  apiVersion: v1
  kind: Node
  name: zone-a-node-0
```

This is exactly what we do in `be-the-scheduler.sh` — we create this Binding ourselves!

---

## YAML Deep Dive

### Ghost Pod (ghost-app.yaml)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mystery-pod
spec:
  schedulerName: ghost-scheduler   # This scheduler DOESN'T EXIST!
  containers:
    - name: mystery
      image: registry.k8s.io/pause:3.9
```

**What happens**:
1. Pod is created with `nodeName: ""` (empty)
2. Default scheduler sees it but ignores it (wrong schedulerName)
3. `ghost-scheduler` doesn't exist, so nobody schedules it
4. Pod stays **Pending forever**

---

### Manual Binding (be-the-scheduler.sh)

```bash
# Create a Binding object to assign pod to node
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Binding
metadata:
  name: mystery-pod
  namespace: default
target:
  apiVersion: v1
  kind: Node
  name: zone-a-node-0
EOF
```

**What happens**:
1. Binding object is created
2. API server sees binding and sets `pod.spec.nodeName = "zone-a-node-0"`
3. Kubelet on that node sees the pod and "runs" it
4. Pod becomes **Running**

---

## Lab Exercises

### Exercise 1: Deploy the Ghost Pod

```bash
kubectl apply -f ghost-app.yaml
```

**Watch the visualizer**: Pod appears in **PENDING QUEUE** and stays there.

Check why:
```bash
kubectl describe pod mystery-pod | grep -A5 Events
```

You'll see no scheduling events because no scheduler is handling it.

---

### Exercise 2: Be the Scheduler!

```bash
./be-the-scheduler.sh zone-a-node-0
```

**Watch the visualizer**: Pod **instantly jumps** from Pending to Running!

You just did what the scheduler does — created a Binding.

---

### Exercise 3: Try a Different Node

```bash
kubectl delete pod mystery-pod
kubectl apply -f ghost-app.yaml
./be-the-scheduler.sh zone-b-node-5
```

Pod lands on whichever node you choose.

---

## When to Use Manual Scheduling

| Use Case | Method |
|----------|--------|
| Testing scheduler behavior | `schedulerName: non-existent` |
| Static system pods | `nodeName` in manifest |
| Custom scheduler development | Create your own binding logic |
| Emergency pod placement | Direct `nodeName` assignment |
| DaemonSet-like behavior | One pod per node with `nodeName` |

---

## Custom Schedulers

You can run multiple schedulers simultaneously:

```yaml
# Pod 1: Use default scheduler
spec:
  schedulerName: default-scheduler

# Pod 2: Use GPU-aware scheduler
spec:
  schedulerName: gpu-scheduler

# Pod 3: Use your custom scheduler
spec:
  schedulerName: my-company-scheduler
```

Each scheduler only handles pods with matching `schedulerName`.

---

## Static Pods

**Static pods** are managed directly by the kubelet without the scheduler:

- Defined in `/etc/kubernetes/manifests/` on the node
- Kubelet watches this directory and runs pods directly
- No scheduler involved at all
- Used for control plane components (kube-apiserver, etcd, etc.)

---

## Difference Summary

| Method | Scheduler Involved? | Use Case |
|--------|---------------------|----------|
| Normal pod | Yes (default-scheduler) | Standard workloads |
| `schedulerName: X` | Yes (scheduler X) | Custom scheduling logic |
| `nodeName: X` | No | Direct placement |
| Binding API | No (you ARE the scheduler) | Scheduler development |
| Static pods | No | Control plane, system services |

---

## Cleanup

```bash
./cleanup.sh
# Or manually:
kubectl delete pod mystery-pod
```

---

## Key Takeaways

1. The scheduler **watches** → **filters** → **scores** → **binds**
2. `schedulerName` lets you use custom schedulers (if they exist)
3. `nodeName` bypasses the scheduler entirely (dangerous!)
4. The **Binding API** is what schedulers use to assign pods
5. Multiple schedulers can run simultaneously
6. Static pods bypass scheduling entirely (managed by kubelet)

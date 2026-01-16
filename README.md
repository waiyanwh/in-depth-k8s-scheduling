# In-Depth Kubernetes Scheduling 🥋

A hands-on lab for mastering Kubernetes scheduling concepts using KWOK (Kubernetes WithOut Kubelet).

## Prerequisites

- [kwokctl](https://kwok.sigs.k8s.io/docs/user/installation/) - KWOK cluster manager
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- Python 3

## Quick Start

```bash
cd 00-setup
./setup-cluster.sh
```

This will create a KWOK cluster with 30 simulated nodes:

| Nodes | Labels | Notes |
|-------|--------|-------|
| 01-10 | `zone=us-east-1a`, `instance-type=standard` | Standard nodes in zone A |
| 11-20 | `zone=us-east-1b`, `instance-type=standard` | Standard nodes in zone B |
| 21-25 | `type=gpu`, `accelerator=nvidia-tesla` | GPU nodes with `gpu=true:NoSchedule` taint |
| 26-30 | `env=production`, `size=large` | Production large instances |

## Cleanup

```bash
kwokctl delete cluster --name scheduling-lab
```

## Project Structure

```
in-depth-k8s-scheduling/
├── 00-setup/
│   ├── generate-nodes.py    # Node manifest generator
│   ├── setup-cluster.sh     # Cluster setup script
│   ├── verify-setup.sh      # Verification script
│   └── nodes.yaml           # Generated after running setup
├── 01-affinity/
│   ├── README.md            # Module instructions
│   ├── gpu-strict.yaml      # Required node affinity example
│   ├── data-processor-flexible.yaml  # Preferred affinity example
│   └── watch-distribution.sh  # Pod distribution visualizer
├── 02-taints/
│   ├── README.md            # Module instructions
│   ├── taint-nodes.sh       # Apply taints to production nodes
│   ├── standard-web-app.yaml  # Blocked app (no toleration)
│   ├── security-monitor-app.yaml  # Allowed app (with toleration)
│   └── simulate-maintenance.sh  # NoExecute eviction demo
├── 03-topology/
│   ├── README.md            # Module instructions
│   ├── zone-aware-app.yaml  # Topology spread constraints
│   ├── clumped-app.yaml     # No constraints (may cluster)
│   └── verify-zones.sh      # Zone distribution analyzer
├── 04-preemption/
│   ├── README.md            # Module instructions
│   ├── priorities.yaml      # Low and high priority classes
│   ├── low-prio-fillers.yaml  # 50 batch pods (victims)
│   ├── high-prio-vip.yaml   # 5 VIP pods (preemptors)
│   └── watch-battle.sh      # Preemption battle monitor
├── 05-manual-scheduling/
│   ├── README.md            # Module instructions
│   ├── ghost-app.yaml       # Pod with non-existent scheduler
│   └── be-the-scheduler.sh  # Manually bind pod to node
└── README.md
```

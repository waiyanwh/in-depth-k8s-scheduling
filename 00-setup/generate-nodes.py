#!/usr/bin/env python3
"""
Generate Kubernetes Node YAML manifest for KWOK-managed fake nodes.
Creates 30 nodes with semantic names for better readability.

GPU nodes have limited pod capacity to demonstrate affinity spillover.
No external dependencies required - generates YAML directly.
"""

import json

def create_node(name, labels, taints=None, max_pods="110"):
    """Create a node dictionary with configurable pod capacity."""
    node = {
        "apiVersion": "v1",
        "kind": "Node",
        "metadata": {
            "name": name,
            "annotations": {
                "kwok.x-k8s.io/node": "fake",
                "node.alpha.kubernetes.io/ttl": "0"
            },
            "labels": {
                "beta.kubernetes.io/arch": "amd64",
                "beta.kubernetes.io/os": "linux",
                "kubernetes.io/arch": "amd64",
                "kubernetes.io/hostname": name,
                "kubernetes.io/os": "linux",
                "kubernetes.io/role": "agent",
                "node-role.kubernetes.io/agent": "",
                "type": "standard"
            }
        },
        "spec": {
            "taints": taints if taints else []
        },
        "status": {
            "allocatable": {
                "cpu": "32",
                "memory": "256Gi",
                "pods": max_pods  # Configurable pod limit
            },
            "capacity": {
                "cpu": "32",
                "memory": "256Gi",
                "pods": max_pods  # Configurable pod limit
            },
            "nodeInfo": {
                "architecture": "amd64",
                "bootID": "",
                "containerRuntimeVersion": "",
                "kernelVersion": "",
                "kubeProxyVersion": "fake",
                "kubeletVersion": "fake",
                "machineID": "",
                "operatingSystem": "linux",
                "osImage": ""
            },
            "phase": "Running",
            "conditions": [{
                "type": "Ready",
                "status": "True",
                "lastHeartbeatTime": "2023-01-01T00:00:00Z",
                "lastTransitionTime": "2023-01-01T00:00:00Z",
                "reason": "KubeletReady",
                "message": "kubelet is posting ready status"
            }]
        }
    }
    node["metadata"]["labels"].update(labels)
    return node


def to_yaml(obj, indent=0):
    """Convert a Python object to YAML string (simple implementation)."""
    prefix = "  " * indent
    
    if isinstance(obj, dict):
        if not obj:
            return "{}"
        lines = []
        for k, v in obj.items():
            if isinstance(v, (dict, list)):
                if not v:
                    lines.append(f"{prefix}{k}: {'{}' if isinstance(v, dict) else '[]'}")
                else:
                    lines.append(f"{prefix}{k}:")
                    lines.append(to_yaml(v, indent + 1))
            elif isinstance(v, bool):
                lines.append(f"{prefix}{k}: {'true' if v else 'false'}")
            elif isinstance(v, str):
                if v == "":
                    lines.append(f'{prefix}{k}: ""')
                else:
                    lines.append(f'{prefix}{k}: "{v}"')
            else:
                lines.append(f"{prefix}{k}: {v}")
        return "\n".join(lines)
    
    elif isinstance(obj, list):
        if not obj:
            return "[]"
        lines = []
        for item in obj:
            if isinstance(item, dict):
                first = True
                for k, v in item.items():
                    if first:
                        if isinstance(v, str):
                            lines.append(f"{prefix}- {k}: \"{v}\"")
                        else:
                            lines.append(f"{prefix}- {k}: {v}")
                        first = False
                    else:
                        if isinstance(v, str):
                            lines.append(f"{prefix}  {k}: \"{v}\"")
                        else:
                            lines.append(f"{prefix}  {k}: {v}")
            else:
                lines.append(f"{prefix}- {item}")
        return "\n".join(lines)
    
    elif isinstance(obj, bool):
        return "true" if obj else "false"
    elif isinstance(obj, str):
        return f'"{obj}"'
    else:
        return str(obj)


def main():
    nodes = []
    
    # 1. Zone A Nodes (Standard) -> Names: zone-a-node-0 to 9
    for i in range(10):
        nodes.append(create_node(
            f"zone-a-node-{i}", 
            {"topology.kubernetes.io/zone": "us-east-1a", "instance-type": "standard"},
            max_pods="10"  # Standard capacity
        ))

    # 2. Zone B Nodes (Standard) -> Names: zone-b-node-0 to 9
    for i in range(10):
        nodes.append(create_node(
            f"zone-b-node-{i}", 
            {"topology.kubernetes.io/zone": "us-east-1b", "instance-type": "standard"},
            max_pods="10"  # Standard capacity
        ))

    # 3. GPU Nodes -> Names: gpu-node-0 to 4
    # LIMITED TO 2 PODS EACH to force spillover in affinity lab!
    for i in range(5):
        nodes.append(create_node(
            f"gpu-node-{i}", 
            {"type": "gpu", "accelerator": "nvidia-tesla"},
            taints=[{"key": "gpu", "value": "true", "effect": "NoSchedule"}],
            max_pods="2"  # Only 2 pods per GPU node!
        ))

    # 4. Production Large Nodes -> Names: prod-node-0 to 4
    # PRE-TAINTED with tier=secure:NoSchedule to reserve for Module 02 lab
    for i in range(5):
        nodes.append(create_node(
            f"prod-node-{i}", 
            {"env": "production", "size": "large"},
            taints=[{"key": "tier", "value": "secure", "effect": "NoSchedule"}],
            max_pods="10"  # Standard capacity
        ))

    # Output as YAML
    yaml_docs = []
    for node in nodes:
        yaml_docs.append(to_yaml(node))
    
    print("---\n" + "\n---\n".join(yaml_docs))


if __name__ == "__main__":
    main()

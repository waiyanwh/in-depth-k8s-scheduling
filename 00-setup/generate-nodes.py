#!/usr/bin/env python3
"""
Generate Kubernetes Node YAML manifest for KWOK-managed fake nodes.
Creates 30 nodes with different configurations for scheduling exercises.

Nodes have limited capacity so pods spill over when nodes are "full".
No external dependencies required - generates YAML directly.
"""


def generate_node_yaml(name: str, labels: dict, taints: list = None, 
                       cpu: str = "4", memory: str = "8Gi", pods: str = "10") -> str:
    """Generate YAML for a single Kubernetes Node with KWOK annotation and capacity."""
    # Build labels section
    labels_lines = [f"    kubernetes.io/hostname: \"{name}\""]
    for k, v in labels.items():
        labels_lines.append(f"    {k}: \"{v}\"")
    labels_yaml = "\n".join(labels_lines)
    
    yaml_content = f"""apiVersion: v1
kind: Node
metadata:
  name: {name}
  labels:
{labels_yaml}
  annotations:
    kwok.x-k8s.io/node: "fake"
spec:"""
    
    if taints:
        yaml_content += "\n  taints:"
        for taint in taints:
            yaml_content += f"""
    - key: "{taint['key']}"
      value: "{taint['value']}"
      effect: "{taint['effect']}\""""
    else:
        yaml_content += " {}"
    
    # Add status with capacity and allocatable resources
    # This is crucial for KWOK to respect resource limits!
    yaml_content += f"""
status:
  allocatable:
    cpu: "{cpu}"
    memory: "{memory}"
    pods: "{pods}"
  capacity:
    cpu: "{cpu}"
    memory: "{memory}"
    pods: "{pods}"
  conditions:
    - type: Ready
      status: "True"
      reason: KubeletReady
      message: "kubelet is ready"
    - type: MemoryPressure
      status: "False"
      reason: KubeletHasSufficientMemory
    - type: DiskPressure
      status: "False"
      reason: KubeletHasNoDiskPressure
    - type: PIDPressure
      status: "False"
      reason: KubeletHasSufficientPID"""
    
    return yaml_content


def generate_all_nodes() -> str:
    """Generate YAML for all 30 nodes."""
    nodes_yaml = []
    
    # Nodes 1-10: us-east-1a zone, standard instance type
    # Medium capacity: 4 CPU, 8Gi memory, max 10 pods
    for i in range(1, 11):
        node = generate_node_yaml(
            name=f"node-{i:02d}",
            labels={
                "topology.kubernetes.io/zone": "us-east-1a",
                "instance-type": "standard"
            },
            cpu="4", memory="8Gi", pods="10"
        )
        nodes_yaml.append(node)
    
    # Nodes 11-20: us-east-1b zone, standard instance type
    for i in range(11, 21):
        node = generate_node_yaml(
            name=f"node-{i:02d}",
            labels={
                "topology.kubernetes.io/zone": "us-east-1b",
                "instance-type": "standard"
            },
            cpu="4", memory="8Gi", pods="10"
        )
        nodes_yaml.append(node)
    
    # Nodes 21-25: GPU nodes with taint
    # Limited capacity: only 2 pods per node to force spillover!
    for i in range(21, 26):
        node = generate_node_yaml(
            name=f"node-{i:02d}",
            labels={
                "type": "gpu",
                "accelerator": "nvidia-tesla"
            },
            taints=[
                {
                    "key": "gpu",
                    "value": "true",
                    "effect": "NoSchedule"
                }
            ],
            cpu="8", memory="32Gi", pods="2"  # Only 2 pods per GPU node!
        )
        nodes_yaml.append(node)
    
    # Nodes 26-30: Production large nodes
    for i in range(26, 31):
        node = generate_node_yaml(
            name=f"node-{i:02d}",
            labels={
                "env": "production",
                "size": "large"
            },
            cpu="8", memory="16Gi", pods="10"
        )
        nodes_yaml.append(node)
    
    return "\n---\n".join(nodes_yaml)


def main():
    """Generate nodes.yaml file."""
    yaml_content = generate_all_nodes()
    
    with open("nodes.yaml", "w") as f:
        f.write(yaml_content)
        f.write("\n")
    
    print("Generated nodes.yaml with 30 nodes (with resource capacity):")
    print("  - Nodes 01-10: zone=us-east-1a, 10 pods max")
    print("  - Nodes 11-20: zone=us-east-1b, 10 pods max")
    print("  - Nodes 21-25: type=gpu (tainted), 2 pods max - FORCES SPILLOVER!")
    print("  - Nodes 26-30: env=production, 10 pods max")


if __name__ == "__main__":
    main()

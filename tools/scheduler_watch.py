#!/usr/bin/env python3
import json
import subprocess
import time
import sys
from datetime import datetime
from rich.live import Live
from rich.table import Table
from rich.layout import Layout
from rich.panel import Panel
from rich.text import Text
from rich.console import Console
from rich import box

# --- Configuration & Constants ---
POD_ICONS = {
    "ai-model": "🧠",
    "data-process": "💾",
    "web-app": "🕸️",
    "sec-monitor": "🛡️",
    "payment": "💳",
    "legacy": "📦",
    "batch": "🧱",
    "realtime": "🚀",
    "mystery": "👻"
}
DEFAULT_ICON = "❓"

# Node Roles and their sorting order
ROLE_ORDER = {
    "GPU": 0,
    "PROD": 1,
    "ZONE A": 2,
    "ZONE B": 3,
    "UNKNOWN": 99
}

def run_command(command):
    """Run a shell command and return its output as a string."""
    try:
        result = subprocess.run(
            command, 
            capture_output=True, 
            text=True, 
            shell=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None

def get_nodes():
    """Fetch nodes from k8s and return parsed JSON."""
    output = run_command("kubectl get nodes -o json")
    if not output:
        return []
    try:
        return json.loads(output).get("items", [])
    except json.JSONDecodeError:
        return []

def get_pods():
    """Fetch pods from k8s and return parsed JSON."""
    output = run_command("kubectl get pods -o wide -o json")
    if not output:
        return []
    try:
        return json.loads(output).get("items", [])
    except json.JSONDecodeError:
        return []

def determine_node_role(name, labels):
    """Determine the role of a node based on name and labels."""
    # Check for Taints/Reserved roles first
    if "gpu-node" in name or labels.get("type") == "gpu":
        return "GPU"
    if "prod-node" in name or labels.get("env") == "production":
        return "PROD"
    
    # Check Zones
    if "zone-a" in name or labels.get("topology.kubernetes.io/zone") == "us-east-1a":
        return "ZONE A"
    if "zone-b" in name or labels.get("topology.kubernetes.io/zone") == "us-east-1b":
        return "ZONE B"
    
    return "UNKNOWN"

def get_pod_icon(pod_name):
    """Return the icon for a pod based on its name prefix."""
    for prefix, icon in POD_ICONS.items():
        if pod_name.startswith(prefix):
            return icon
    return DEFAULT_ICON

def generate_layout() -> Layout:
    """Define the UI layout."""
    layout = Layout()
    layout.split(
        Layout(name="header", size=3),
        Layout(name="pending", size=6),
        Layout(name="main", ratio=1)
    )
    return layout

def generate_pending_panel(pending_pods):
    """Create a panel showing pending pods."""
    content = ""
    if not pending_pods:
        content = "[green]No pending pods[/green]"
    else:
        # Group by priority class if available, otherwise just list
        for pod in pending_pods:
            metadata = pod.get("metadata", {})
            name = metadata.get("name", "unknown")
            spec = pod.get("spec", {})
            prio_class = spec.get("priorityClassName", "default")
            
            icon = get_pod_icon(name)
            content += f"{icon} [bold]{name}[/bold] (Prio: {prio_class})\n"
            
    return Panel(content, title="[yellow]Pending Queue (Stuck Pods)[/yellow]", border_style="yellow")

def generate_cluster_table(nodes, pods):
    """Create the main cluster status table."""
    table = Table(title="Cluster Status", expand=True, box=box.ROUNDED, show_lines=True)
    
    table.add_column("Node", style="cyan", no_wrap=True)
    table.add_column("Role", style="magenta")
    table.add_column("Taints", justify="center")
    table.add_column("Capacity", justify="center")
    table.add_column("Visual Map", ratio=1)

    # organize data
    processed_nodes = []
    
    node_pod_map = {node["metadata"]["name"]: [] for node in nodes}
    
    # Map pods to nodes
    for pod in pods:
        spec = pod.get("spec", {})
        node_name = spec.get("nodeName")
        status = pod.get("status", {})
        phase = status.get("phase")
        
        if node_name and node_name in node_pod_map and phase == "Running":
            node_pod_map[node_name].append(pod)

    for node in nodes:
        metadata = node.get("metadata", {})
        name = metadata.get("name", "unknown")
        labels = metadata.get("labels", {})
        spec = node.get("spec", {})
        taints = spec.get("taints", [])
        
        role = determine_node_role(name, labels)
        
        # Determine Capacity (Just pod count vs abstract max for visual)
        # Using strict limits from requirements: 2 for GPU, 10 for others?
        # The prompt examples: "2/2" for GPU, "0/10" for standard.
        # Let's derive max from role or leave generic if unknown.
        max_pods = 10
        if role == "GPU":
            max_pods = 2
        elif role == "PROD":
            max_pods = 5 # Assumption or standard
        
        # Actually user said: "2/2 for GPU nodes, 0/10 for standard". 
        # I will stick to 2 for GPU, 10 for others for now unless I see capacity in status (which is raw resource).
        # Simpler to hardcode based on role as implied by "Capacity" column request example.
        if role == "GPU": 
            capacity_limit = 2
        else:
            capacity_limit = 10
            
        running_pods = node_pod_map.get(name, [])
        used = len(running_pods)
        
        capacity_str = f"{used}/{capacity_limit}"
        if used >= capacity_limit:
            capacity_str = f"[red]{capacity_str}[/red]"
        else:
            capacity_str = f"[green]{capacity_str}[/green]"

        # Taints visual
        taint_visual = ""
        if taints:
            taint_visual = "⛔"

        # Visual Map
        visual_map = ""
        for pod in running_pods:
            pod_name = pod["metadata"]["name"]
            visual_map += get_pod_icon(pod_name) + " "

        processed_nodes.append({
            "name": name,
            "role": role,
            "role_sort": ROLE_ORDER.get(role, 99),
            "taints": taint_visual,
            "capacity": capacity_str,
            "visual": visual_map
        })

    # Sort nodes by Role then Name
    processed_nodes.sort(key=lambda x: (x["role_sort"], x["name"]))

    current_role = None
    for node in processed_nodes:
        # Add section separation if role changes (optional, or just grouped rows)
        # Rich tables don't support row grouping headers easily in standard mode, 
        # but we can just list them sorted.
        role_display = node["role"]
        
        # Add icons to role
        if node["role"] == "GPU": role_display = "⚡ GPU"
        elif node["role"] == "PROD": role_display = "🔒 PROD"
        elif node["role"] == "ZONE A": role_display = "📍 Zone A"
        elif node["role"] == "ZONE B": role_display = "📍 Zone B"
        
        table.add_row(
            node["name"],
            role_display,
            node["taints"],
            node["capacity"],
            node["visual"]
        )

    return table

def main():
    console = Console()
    layout = generate_layout()
    
    layout["header"].update(Panel(Text("Kubernetes Scheduling Lab - Global Dashboard", justify="center", style="bold white on blue")))
    
    with Live(layout, refresh_per_second=1, screen=True):
        while True:
            try:
                nodes = get_nodes()
                pods = get_pods()
                
                # Filter Pending Pods
                pending_pods = []
                for pod in pods:
                    status = pod.get("status", {})
                    phase = status.get("phase")
                    if phase == "Pending":
                        pending_pods.append(pod)
                
                layout["pending"].update(generate_pending_panel(pending_pods))
                layout["main"].update(generate_cluster_table(nodes, pods))
                
                # Manual grouping by clearing and re-adding not efficient for live? 
                # Actually generating new table object every frame is fine for rich.live.
                
                time.sleep(1)
            except KeyboardInterrupt:
                sys.exit(0)
            except Exception as e:
                # In case of error, just print to header or ignore to keep running
                layout["header"].update(Panel(Text(f"Error: {str(e)}", style="bold white on red")))
                time.sleep(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass

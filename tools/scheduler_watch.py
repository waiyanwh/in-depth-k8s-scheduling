import subprocess
import json
import time
import os
import sys
import shutil

# --- Configuration ---
# Map pod name prefixes to specific icons for the stream
ICON_MAP = {
    "ai-model": "🧠",      # Lab 1: GPU Strict
    "data-process": "💾",  # Lab 1: Flexible
    "web-app": "🕸️ ",      # Lab 2: Standard Web
    "sec-monitor": "🛡️ ",  # Lab 2: Security
    "payment": "💳",       # Lab 3: Zone Aware
    "legacy": "📦",        # Lab 3: Clumped
    "batch": "🧱",         # Lab 4: Low Prio (Bricks)
    "realtime": "🚀",      # Lab 4: High Prio (Rocket)
    "mystery": "👻",       # Lab 5: Manual
    "special": "👽",       # Lab 5: Custom
}
DEFAULT_ICON = "🟢"

def run_kubectl(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0: return None
        return json.loads(result.stdout)
    except: return None

def get_pod_icon(name):
    for key, icon in ICON_MAP.items():
        if key in name:
            return icon
    return DEFAULT_ICON

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def main():
    print("Starting Advanced K8s Visualizer... (Press Ctrl+C to stop)")
    
    while True:
        # Fetch data
        nodes_data = run_kubectl("kubectl get nodes -o json")
        pods_data = run_kubectl("kubectl get pods -o wide -o json")
        
        if not nodes_data or not pods_data:
            print("Connecting to cluster...")
            time.sleep(1)
            continue

        # 1. Process Nodes
        nodes = {}
        for n in nodes_data['items']:
            name = n['metadata']['name']
            labels = n['metadata']['labels']
            # Detect Role/Zone
            zone = labels.get('topology.kubernetes.io/zone', 'no-zone')
            if "gpu" in labels.get('type', ''): zone = "⚡ GPU POOL"
            if "production" in labels.get('env', ''): zone = "🔒 PROD POOL"
            
            # Detect Taints
            taints = n.get('spec', {}).get('taints', [])
            taint_icon = "⛔" if taints else "  "
            
            nodes[name] = {
                'zone': zone, 
                'taint': taint_icon, 
                'pods': [],
                'capacity': int(n['status']['capacity'].get('pods', 110)) 
            }

        # 2. Process Pods
        pending_pods = []
        for p in pods_data['items']:
            name = p['metadata']['name']
            phase = p['status']['phase']
            node_name = p['spec'].get('nodeName')
            
            icon = get_pod_icon(name)
            
            if phase == "Pending":
                pending_pods.append(f"{icon} {name}")
            elif node_name in nodes:
                nodes[node_name]['pods'].append(icon)

        # 3. Render UI
        clear_screen()
        print("\n 🔭 K8s SCHEDULER DOJO | Live Stream Mode")
        print(" =========================================")

        # Draw Pending Queue
        if pending_pods:
            print(f"\n ⚠️  PENDING QUEUE ({len(pending_pods)}):")
            print(f" {' '.join(pending_pods)}")
        else:
            print("\n ✅  Pending Queue: Empty")

        print("\n" + "-"*70)

        # Group Nodes by Zone for cleaner display
        nodes_by_zone = {}
        for n_name, n_data in nodes.items():
            z = n_data['zone']
            if z not in nodes_by_zone: nodes_by_zone[z] = []
            nodes_by_zone[z].append((n_name, n_data))

        # Sort zones to keep order: Zone A, Zone B, GPU, Prod
        sorted_zones = sorted(nodes_by_zone.keys())

        for zone in sorted_zones:
            print(f"\n 📍 {zone.upper()}")
            # Sort nodes by name within zone
            for n_name, n_data in sorted(nodes_by_zone[zone], key=lambda x: x[0]):
                pod_list = n_data['pods']
                pod_count = len(pod_list)
                
                # Create a visual "bar" of icons
                # We strip spaces from icons to make them tight: "🧠🧠🧠"
                visual_bar = "".join([p.strip() for p in pod_list])
                
                # Simple capacity visualization
                # Assuming max visual length of ~50 chars for the stream
                print(f" {n_data['taint']} {n_name:<15} │ {visual_bar}")

        print("\n" + "="*70)
        print(" Legend: 🧠=AI | 💾=Data | 🛡️=Sec | 💳=Pay | 👻=Manual | 🧱=Batch | 🚀=VIP")
        
        time.sleep(0.5) # Faster refresh rate for smooth feel

if __name__ == "__main__":
    main()

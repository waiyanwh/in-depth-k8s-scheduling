import subprocess
import json
import time
import os
import sys

def run_kubectl(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0: return None
        return json.loads(result.stdout)
    except: return None

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def main():
    print("Starting K8s Observer... Press Ctrl+C to stop.")
    while True:
        nodes_data = run_kubectl("kubectl get nodes -o json")
        pods_data = run_kubectl("kubectl get pods -o json")
        
        if not nodes_data or not pods_data:
            print("Connecting to cluster...")
            time.sleep(1)
            continue

        # 1. Map Nodes
        nodes = {}
        for n in nodes_data['items']:
            name = n['metadata']['name']
            labels = n['metadata']['labels']
            zone = labels.get('topology.kubernetes.io/zone', 'unknown')
            n_type = labels.get('type', 'std')
            # Check if node is tainted
            tainted = "⛔" if n.get('spec', {}).get('taints') else "  "
            
            nodes[name] = {'zone': zone, 'type': n_type, 'taint': tainted, 'pods': []}

        # 2. Map Pods
        pending_pods = []
        for p in pods_data['items']:
            name = p['metadata']['name']
            status = p['status']['phase']
            node_name = p['spec'].get('nodeName')
            prio = p['spec'].get('priorityClassName', 'default')
            
            if status == "Pending":
                pending_pods.append(f"{name} [{prio}]")
            elif node_name in nodes:
                # Shorten name for display (e.g., 'web-app-x8s9d' -> 'web-app')
                short_name = name.rsplit('-', 1)[0]
                nodes[node_name]['pods'].append(short_name)

        # 3. Render UI
        clear_screen()
        print("🔭 K8s SCHEDULING LAB - LIVE VIEW")
        print("===================================")
        
        # Section A: The Pending Queue
        print(f"\n⚠️  PENDING QUEUE ({len(pending_pods)}):")
        if not pending_pods: print("   (Empty)")
        for p in pending_pods: print(f"   ⏳ {p}")
        print("\n" + "-"*60)

        # Section B: The Cluster Map
        # Sort by Zone -> Type -> Name
        sorted_nodes = sorted(nodes.keys(), key=lambda x: (nodes[x]['zone'], nodes[x]['type'], x))
        
        current_zone = ""
        for n in sorted_nodes:
            node = nodes[n]
            if node['zone'] != current_zone:
                print(f"\n📍 ZONE: {node['zone'].upper()}")
                current_zone = node['zone']
            
            # Visual representation of pods
            # We group similar pods: "web-app(x5)"
            pod_counts = {}
            for p in node['pods']:
                pod_counts[p] = pod_counts.get(p, 0) + 1
            
            pod_str = ""
            for p_name, count in pod_counts.items():
                pod_str += f"🟢 {p_name}"
                if count > 1: pod_str += f"(x{count})"
                pod_str += "  "

            print(f"  {node['taint']} [{n:<15}] ({node['type']:<4}) │ {pod_str}")

        print("\n" + "="*35)
        print("Legend: ⛔ = Tainted Node | ⏳ = Pending Pod")
        time.sleep(1)

if __name__ == "__main__":
    main()

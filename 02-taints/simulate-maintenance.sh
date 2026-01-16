#!/bin/bash
#
# Simulate Node Maintenance using NoExecute taint
# This demonstrates how NoExecute evicts running pods immediately
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Pick a standard node (us-east-1a zone)
NODE="zone-a-node-7"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Simulating Node Maintenance (NoExecute)           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if node exists
if ! kubectl get node "$NODE" &>/dev/null; then
    echo -e "${RED}Node $NODE not found!${NC}"
    echo "Make sure you've run the setup script first."
    exit 1
fi

echo -e "${CYAN}Step 1: Check current pods on $NODE${NC}"
echo ""
PODS_BEFORE=$(kubectl get pods -o wide --no-headers 2>/dev/null | grep "$NODE" || true)
if [ -z "$PODS_BEFORE" ]; then
    echo -e "${YELLOW}No pods currently running on $NODE${NC}"
    echo ""
    echo "Deploy some workloads first to see the eviction in action:"
    echo "  kubectl apply -f ../01-affinity/data-processor-flexible.yaml"
    echo ""
else
    echo "$PODS_BEFORE" | head -10
    POD_COUNT=$(echo "$PODS_BEFORE" | wc -l | tr -d ' ')
    echo ""
    echo -e "${GREEN}Found $POD_COUNT pod(s) on $NODE${NC}"
fi

echo ""
echo -e "${CYAN}Step 2: Applying NoExecute taint to $NODE${NC}"
echo -e "${RED}⚠️  This will EVICT all pods from this node immediately!${NC}"
echo ""
read -p "Press Enter to continue (or Ctrl+C to cancel)..."
echo ""

kubectl taint node "$NODE" outage=true:NoExecute --overwrite
echo -e "${GREEN}Taint applied: outage=true:NoExecute${NC}"

echo ""
echo -e "${CYAN}Step 3: Waiting 5 seconds for eviction...${NC}"
sleep 5

echo ""
echo -e "${CYAN}Step 4: Check pods on $NODE after eviction${NC}"
echo ""
PODS_AFTER=$(kubectl get pods -o wide --no-headers 2>/dev/null | grep "$NODE" || true)
if [ -z "$PODS_AFTER" ]; then
    echo -e "${GREEN}✓ All pods have been evicted from $NODE!${NC}"
else
    echo -e "${YELLOW}Remaining pods on $NODE:${NC}"
    echo "$PODS_AFTER"
fi

echo ""
echo -e "${CYAN}Step 5: Check pod status (look for Pending pods)${NC}"
echo ""
kubectl get pods -o wide 2>/dev/null | head -15

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}Maintenance simulation complete!${NC}"
echo ""
echo "What happened:"
echo "  • NoExecute taint immediately evicts running pods"
echo "  • Pods without matching toleration are terminated"
echo "  • Scheduler will reschedule them to other available nodes"
echo ""
echo "To restore the node:"
echo "  kubectl taint node $NODE outage=true:NoExecute-"
echo ""

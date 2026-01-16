#!/bin/bash
#
# Taint production nodes (26-30) with tier=secure:NoSchedule
# This creates an "electric fence" - only pods with the matching toleration can schedule
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Tainting Production Nodes                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Get all production nodes
PROD_NODES=$(kubectl get nodes -l env=production --no-headers -o custom-columns=":metadata.name")

if [ -z "$PROD_NODES" ]; then
    echo -e "${RED}No production nodes found!${NC}"
    echo "Make sure you've run the setup script first: cd ../00-setup && ./setup-cluster.sh"
    exit 1
fi

echo -e "${YELLOW}Applying taint 'tier=secure:NoSchedule' to production nodes...${NC}"
echo ""

for node in $PROD_NODES; do
    echo -n "  Tainting $node... "
    # Use --overwrite in case the taint already exists
    kubectl taint node "$node" tier=secure:NoSchedule --overwrite 2>/dev/null || true
    echo -e "${GREEN}done${NC}"
done

echo ""
echo -e "${GREEN}Production nodes are now tainted!${NC}"
echo ""
echo "Verify with:"
echo "  kubectl describe node node-26 | grep -A5 Taints"
echo ""
echo "To remove taints later:"
echo "  kubectl taint node node-26 tier=secure:NoSchedule-"
echo "  (or run: ./untaint-nodes.sh)"

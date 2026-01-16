#!/bin/bash
#
# Verify the KWOK cluster setup
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Cluster Setup Verification                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${YELLOW}Checking Node Counts...${NC}"
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
echo -e "${GREEN}Total nodes: ${TOTAL_NODES}${NC}"
echo ""

echo -e "${YELLOW}Checking GPU Nodes...${NC}"
kubectl get nodes -l type=gpu
echo ""

echo -e "${YELLOW}Checking Zone Distribution...${NC}"
echo "us-east-1a nodes:"
kubectl get nodes -l topology.kubernetes.io/zone=us-east-1a --no-headers | wc -l | tr -d ' '
echo "us-east-1b nodes:"
kubectl get nodes -l topology.kubernetes.io/zone=us-east-1b --no-headers | wc -l | tr -d ' '
echo ""

echo -e "${YELLOW}Checking Production Nodes...${NC}"
kubectl get nodes -l env=production
echo ""

echo -e "${GREEN}Verification complete!${NC}"

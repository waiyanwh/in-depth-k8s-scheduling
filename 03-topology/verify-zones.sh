#!/bin/bash
#
# Verify pod distribution across availability zones
# Shows how many pods are in each zone
# Compatible with Bash 3.x (macOS default)
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Zone Distribution Analyzer                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Get all running pods with their nodes
PODS=$(kubectl get pods -o wide --no-headers 2>/dev/null | grep -v Pending || true)

if [ -z "$PODS" ]; then
    echo -e "${YELLOW}No running pods found in the default namespace.${NC}"
    echo ""
    echo "Deploy workloads first:"
    echo "  kubectl apply -f zone-aware-app.yaml"
    echo "  kubectl apply -f clumped-app.yaml"
    exit 0
fi

# Count pods per zone
ZONE_A_COUNT=0
ZONE_B_COUNT=0
UNKNOWN_COUNT=0

# Process each pod
while IFS= read -r line; do
    NODE=$(echo "$line" | awk '{print $7}')
    
    # Determine zone based on node name
    # Nodes 01-10 = us-east-1a, Nodes 11-20 = us-east-1b
    NODE_NUM=$(echo "$NODE" | sed 's/node-//' | sed 's/^0//')
    
    if [ -n "$NODE_NUM" ] && [ "$NODE_NUM" -ge 1 ] 2>/dev/null && [ "$NODE_NUM" -le 10 ]; then
        ZONE_A_COUNT=$((ZONE_A_COUNT + 1))
    elif [ -n "$NODE_NUM" ] && [ "$NODE_NUM" -ge 11 ] 2>/dev/null && [ "$NODE_NUM" -le 20 ]; then
        ZONE_B_COUNT=$((ZONE_B_COUNT + 1))
    else
        UNKNOWN_COUNT=$((UNKNOWN_COUNT + 1))
    fi
done <<< "$PODS"

TOTAL=$((ZONE_A_COUNT + ZONE_B_COUNT + UNKNOWN_COUNT))

# Print overall summary
echo -e "${GREEN}═══ Overall Zone Distribution ═══${NC}"
echo ""
printf "  ${CYAN}%-25s${NC} %d pods\n" "Zone us-east-1a:" "$ZONE_A_COUNT"
printf "  ${MAGENTA}%-25s${NC} %d pods\n" "Zone us-east-1b:" "$ZONE_B_COUNT"
if [ "$UNKNOWN_COUNT" -gt 0 ]; then
    printf "  %-25s %d pods\n" "Other (GPU/Prod):" "$UNKNOWN_COUNT"
fi
echo "  ─────────────────────────────────"
printf "  %-25s %d pods\n" "Total:" "$TOTAL"

# Per-app breakdown
echo ""
echo -e "${GREEN}═══ Per-Application Breakdown ═══${NC}"
echo ""

# Get unique app names
APPS=$(kubectl get pods --no-headers -o custom-columns=":metadata.labels.app" 2>/dev/null | sort -u | grep -v '<none>' || true)

for app in $APPS; do
    APP_PODS=$(kubectl get pods -l app="$app" -o wide --no-headers 2>/dev/null | grep -v Pending || true)
    
    if [ -z "$APP_PODS" ]; then
        continue
    fi
    
    APP_ZONE_A=0
    APP_ZONE_B=0
    APP_OTHER=0
    
    while IFS= read -r line; do
        NODE=$(echo "$line" | awk '{print $7}')
        NODE_NUM=$(echo "$NODE" | sed 's/node-//' | sed 's/^0//')
        
        if [ -n "$NODE_NUM" ] && [ "$NODE_NUM" -ge 1 ] 2>/dev/null && [ "$NODE_NUM" -le 10 ]; then
            APP_ZONE_A=$((APP_ZONE_A + 1))
        elif [ -n "$NODE_NUM" ] && [ "$NODE_NUM" -ge 11 ] 2>/dev/null && [ "$NODE_NUM" -le 20 ]; then
            APP_ZONE_B=$((APP_ZONE_B + 1))
        else
            APP_OTHER=$((APP_OTHER + 1))
        fi
    done <<< "$APP_PODS"
    
    APP_TOTAL=$((APP_ZONE_A + APP_ZONE_B + APP_OTHER))
    
    echo -e "${YELLOW}$app:${NC}"
    printf "    ${CYAN}%-20s${NC} %d pods\n" "us-east-1a:" "$APP_ZONE_A"
    printf "    ${MAGENTA}%-20s${NC} %d pods\n" "us-east-1b:" "$APP_ZONE_B"
    if [ "$APP_OTHER" -gt 0 ]; then
        printf "    %-20s %d pods\n" "other:" "$APP_OTHER"
    fi
    
    # Calculate skew (only between zone A and B)
    if [ "$APP_ZONE_A" -ge "$APP_ZONE_B" ]; then
        SKEW=$((APP_ZONE_A - APP_ZONE_B))
    else
        SKEW=$((APP_ZONE_B - APP_ZONE_A))
    fi
    
    if [ "$SKEW" -le 1 ]; then
        echo -e "    ${GREEN}✓ Skew: $SKEW (balanced)${NC}"
    else
        echo -e "    ${RED}✗ Skew: $SKEW (imbalanced!)${NC}"
    fi
    echo ""
done

echo "════════════════════════════════════════════════════════════"

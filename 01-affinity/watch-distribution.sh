#!/bin/bash
#
# Watch pod distribution across GPU vs Standard nodes
# Uses label-based detection for semantic node names
# Updates every 2 seconds
#

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear_screen() {
    clear
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           Pod Distribution Watcher (Ctrl+C to exit)        ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${CYAN}GPU Nodes: gpu-node-0 to gpu-node-4 (type=gpu)${NC}"
    echo -e "${CYAN}Standard Nodes: zone-a-node-*, zone-b-node-*, prod-node-*${NC}"
    echo ""
}

# Get list of GPU nodes by label
get_gpu_nodes() {
    kubectl get nodes -l type=gpu --no-headers -o custom-columns=":metadata.name" 2>/dev/null | tr '\n' ' '
}

is_gpu_node() {
    local node=$1
    echo "$node" | grep -q "^gpu-"
}

watch_distribution() {
    while true; do
        clear_screen
        print_header

        # Get all pods with their nodes
        PODS_INFO=$(kubectl get pods -o wide --no-headers 2>/dev/null)

        if [ -z "$PODS_INFO" ]; then
            echo -e "${YELLOW}No pods found in the default namespace.${NC}"
            echo ""
            echo "Deploy workloads to see distribution:"
            echo "  kubectl apply -f gpu-strict.yaml"
            echo "  kubectl apply -f data-processor-flexible.yaml"
        else
            # Count pods on GPU nodes
            GPU_POD_COUNT=0
            STANDARD_POD_COUNT=0
            PENDING_COUNT=0

            while IFS= read -r line; do
                POD_NAME=$(echo "$line" | awk '{print $1}')
                STATUS=$(echo "$line" | awk '{print $3}')
                NODE=$(echo "$line" | awk '{print $7}')

                if [ "$STATUS" == "Pending" ] || [ "$NODE" == "<none>" ]; then
                    ((PENDING_COUNT++))
                elif is_gpu_node "$NODE"; then
                    ((GPU_POD_COUNT++))
                else
                    ((STANDARD_POD_COUNT++))
                fi
            done <<< "$PODS_INFO"

            TOTAL=$((GPU_POD_COUNT + STANDARD_POD_COUNT + PENDING_COUNT))

            echo -e "${GREEN}═══ Pod Distribution Summary ═══${NC}"
            echo ""
            printf "  ${MAGENTA}%-20s${NC} %d pods\n" "🎮 GPU Nodes:" "$GPU_POD_COUNT"
            printf "  ${YELLOW}%-20s${NC} %d pods\n" "💻 Standard Nodes:" "$STANDARD_POD_COUNT"
            printf "  ${CYAN}%-20s${NC} %d pods\n" "⏳ Pending:" "$PENDING_COUNT"
            echo "  ────────────────────────────"
            printf "  %-20s %d pods\n" "📊 Total:" "$TOTAL"
            echo ""

            # Show breakdown by deployment
            echo -e "${GREEN}═══ By Deployment ═══${NC}"
            echo ""

            # AI Model Training (strict)
            AI_PODS=$(echo "$PODS_INFO" | grep "ai-model-training" || true)
            if [ -n "$AI_PODS" ]; then
                AI_TOTAL=$(echo "$AI_PODS" | wc -l | tr -d ' ')
                AI_RUNNING=$(echo "$AI_PODS" | grep -c "Running" || echo "0")
                AI_PENDING=$(echo "$AI_PODS" | grep -c "Pending" || echo "0")
                echo -e "  ${MAGENTA}ai-model-training (strict):${NC}"
                echo "    Running: $AI_RUNNING | Pending: $AI_PENDING | Total: $AI_TOTAL"
            fi

            # Data Processor (flexible)
            DP_PODS=$(echo "$PODS_INFO" | grep "data-processor" || true)
            if [ -n "$DP_PODS" ]; then
                DP_TOTAL=$(echo "$DP_PODS" | wc -l | tr -d ' ')
                DP_GPU=0
                DP_STD=0
                DP_PENDING=0

                while IFS= read -r line; do
                    STATUS=$(echo "$line" | awk '{print $3}')
                    NODE=$(echo "$line" | awk '{print $7}')

                    if [ "$STATUS" == "Pending" ] || [ "$NODE" == "<none>" ]; then
                        ((DP_PENDING++))
                    elif is_gpu_node "$NODE"; then
                        ((DP_GPU++))
                    else
                        ((DP_STD++))
                    fi
                done <<< "$DP_PODS"

                echo -e "  ${YELLOW}data-processor (flexible):${NC}"
                echo "    On GPU: $DP_GPU | On Standard: $DP_STD | Pending: $DP_PENDING | Total: $DP_TOTAL"
            fi

            echo ""
            echo -e "${GREEN}═══ Pod Details ═══${NC}"
            echo ""
            kubectl get pods -o wide 2>/dev/null | head -20
            
            TOTAL_LINES=$(kubectl get pods --no-headers 2>/dev/null | wc -l | tr -d ' ')
            if [ "$TOTAL_LINES" -gt 19 ]; then
                echo "... and $((TOTAL_LINES - 19)) more pods"
            fi
        fi

        echo ""
        echo -e "${CYAN}Last updated: $(date '+%H:%M:%S')${NC}"
        sleep 2
    done
}

# Run the watcher
watch_distribution

#!/bin/bash
#
# Watch the priority battle unfold!
# Shows real-time pod counts by priority class
#

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear_screen() {
    clear
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           Priority Preemption Battle (Ctrl+C to exit)       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

watch_battle() {
    while true; do
        clear_screen
        print_header
        
        # Count VIP (high priority) pods
        VIP_RUNNING=$(kubectl get pods -l app=realtime-analytics --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
        VIP_PENDING=$(kubectl get pods -l app=realtime-analytics --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
        VIP_TOTAL=$(kubectl get pods -l app=realtime-analytics --no-headers 2>/dev/null | wc -l | tr -d ' ')
        
        # Count batch (low priority) pods
        BATCH_RUNNING=$(kubectl get pods -l app=batch-processing --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
        BATCH_PENDING=$(kubectl get pods -l app=batch-processing --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
        BATCH_TOTAL=$(kubectl get pods -l app=batch-processing --no-headers 2>/dev/null | wc -l | tr -d ' ')
        
        echo -e "${GREEN}═══ Pod Status by Priority ═══${NC}"
        echo ""
        
        # VIP Section
        echo -e "${MAGENTA}👑 HIGH PRIORITY (VIP) - realtime-analytics${NC}"
        echo -e "   Priority Value: ${CYAN}1,000,000${NC}"
        printf "   Running: ${GREEN}%d${NC} | Pending: ${YELLOW}%d${NC} | Total: %d\n" "$VIP_RUNNING" "$VIP_PENDING" "$VIP_TOTAL"
        
        # Progress bar for VIP
        if [ "$VIP_TOTAL" -gt 0 ]; then
            PERCENT=$((VIP_RUNNING * 100 / VIP_TOTAL))
            BAR_WIDTH=30
            FILLED=$((VIP_RUNNING * BAR_WIDTH / VIP_TOTAL))
            echo -n "   ["
            for ((i=0; i<FILLED; i++)); do echo -n "█"; done
            for ((i=FILLED; i<BAR_WIDTH; i++)); do echo -n "░"; done
            echo "] ${PERCENT}%"
        fi
        echo ""
        
        # Batch Section
        echo -e "${YELLOW}📦 LOW PRIORITY (Batch) - batch-processing${NC}"
        echo -e "   Priority Value: ${CYAN}1,000${NC}"
        printf "   Running: ${GREEN}%d${NC} | Pending: ${YELLOW}%d${NC} | Total: %d\n" "$BATCH_RUNNING" "$BATCH_PENDING" "$BATCH_TOTAL"
        
        # Progress bar for Batch
        if [ "$BATCH_TOTAL" -gt 0 ]; then
            PERCENT=$((BATCH_RUNNING * 100 / BATCH_TOTAL))
            BAR_WIDTH=30
            FILLED=$((BATCH_RUNNING * BAR_WIDTH / BATCH_TOTAL))
            echo -n "   ["
            for ((i=0; i<FILLED; i++)); do echo -n "█"; done
            for ((i=FILLED; i<BAR_WIDTH; i++)); do echo -n "░"; done
            echo "] ${PERCENT}%"
        fi
        echo ""
        
        # Battle Status
        echo -e "${GREEN}═══ Battle Status ═══${NC}"
        echo ""
        if [ "$VIP_TOTAL" -eq 0 ] && [ "$BATCH_TOTAL" -eq 0 ]; then
            echo -e "   ${YELLOW}⏳ No combatants deployed yet!${NC}"
            echo ""
            echo "   Deploy the battle:"
            echo "     1. kubectl apply -f priorities.yaml"
            echo "     2. kubectl apply -f low-prio-fillers.yaml"
            echo "     3. Wait for batch pods to fill GPU nodes"
            echo "     4. kubectl apply -f high-prio-vip.yaml"
            echo "     5. Watch the preemption!"
        elif [ "$VIP_TOTAL" -eq 0 ]; then
            echo -e "   ${YELLOW}📦 Batch jobs are filling GPU nodes...${NC}"
            echo "   Deploy VIP pods to trigger preemption:"
            echo "     kubectl apply -f high-prio-vip.yaml"
        elif [ "$VIP_RUNNING" -eq "$VIP_TOTAL" ]; then
            echo -e "   ${GREEN}✓ VIP pods have claimed their spots!${NC}"
            echo -e "   ${YELLOW}Some batch pods were preempted to make room.${NC}"
        else
            echo -e "   ${CYAN}⚔️  Battle in progress...${NC}"
            echo "   VIP pods are preempting batch pods!"
        fi
        
        echo ""
        echo -e "${GREEN}═══ Recent Events ═══${NC}"
        echo ""
        kubectl get events --field-selector reason=Preempted --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || echo "   No preemption events yet"
        
        echo ""
        echo -e "${CYAN}Last updated: $(date '+%H:%M:%S')${NC}"
        sleep 1
    done
}

# Run the watcher
watch_battle

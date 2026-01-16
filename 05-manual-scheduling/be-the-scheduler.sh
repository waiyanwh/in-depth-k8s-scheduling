#!/bin/bash
#
# BE THE SCHEDULER!
# Manually bind a pod to a node using the Binding API
# This bypasses the Kubernetes scheduler entirely.
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Default node or use argument
TARGET_NODE="${1:-node-01}"
POD_NAME="mystery-pod"
NAMESPACE="${2:-default}"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              BE THE SCHEDULER! 🎮                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if pod exists
if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo -e "${RED}Pod '$POD_NAME' not found!${NC}"
    echo ""
    echo "Create it first:"
    echo "  kubectl apply -f ghost-app.yaml"
    exit 1
fi

# Check current status
echo -e "${CYAN}Step 1: Check current pod status${NC}"
echo ""
kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o wide
echo ""

STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
CURRENT_NODE=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')

if [ "$STATUS" == "Running" ]; then
    echo -e "${YELLOW}Pod is already running on node: $CURRENT_NODE${NC}"
    echo ""
    echo "To try again, delete and recreate the pod:"
    echo "  kubectl delete -f ghost-app.yaml"
    echo "  kubectl apply -f ghost-app.yaml"
    exit 0
fi

if [ -n "$CURRENT_NODE" ]; then
    echo -e "${YELLOW}Pod already has nodeName set: $CURRENT_NODE${NC}"
    exit 0
fi

echo -e "${CYAN}Step 2: Check target node exists${NC}"
echo ""
if ! kubectl get node "$TARGET_NODE" &>/dev/null; then
    echo -e "${RED}Node '$TARGET_NODE' not found!${NC}"
    echo ""
    echo "Available nodes:"
    kubectl get nodes --no-headers | awk '{print "  " $1}'
    echo ""
    echo "Usage: $0 [node-name]"
    exit 1
fi
echo -e "${GREEN}Target node '$TARGET_NODE' exists ✓${NC}"
echo ""

echo -e "${CYAN}Step 3: Create Binding object to assign pod to node${NC}"
echo ""

# Create a temporary file for the binding
BINDING_FILE=$(mktemp)
cat > "$BINDING_FILE" << BINDING_EOF
apiVersion: v1
kind: Binding
metadata:
  name: $POD_NAME
  namespace: $NAMESPACE
target:
  apiVersion: v1
  kind: Node
  name: $TARGET_NODE
BINDING_EOF

# Apply the binding
kubectl create -f "$BINDING_FILE" 2>/dev/null && echo -e "${GREEN}Binding created!${NC}" || echo -e "${YELLOW}Binding may already exist${NC}"

# Clean up temp file
rm -f "$BINDING_FILE"

echo ""
echo -e "${CYAN}Step 4: Verify pod is now scheduled${NC}"
echo ""
sleep 2
kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o wide

echo ""
echo "════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}🎉 You just became the scheduler!${NC}"
echo ""
echo "What happened:"
echo "  1. Pod was Pending (ghost-scheduler doesn't exist)"
echo "  2. You created a Binding object for '$TARGET_NODE'"
echo "  3. Kubelet (KWOK) saw the binding and 'started' the pod"
echo "  4. Default scheduler was completely bypassed!"
echo ""
echo "This is exactly how the real kube-scheduler works internally."
echo ""

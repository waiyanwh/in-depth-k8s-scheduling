#!/bin/bash
#
# Setup script for In-Depth Kubernetes Scheduling Lab
# Creates a KWOK cluster with 30 simulated nodes for scheduling exercises
#

set -e

CLUSTER_NAME="scheduling-lab"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kwokctl is installed
check_kwokctl() {
    echo_info "Checking if kwokctl is installed..."
    if ! command -v kwokctl &> /dev/null; then
        echo_error "kwokctl is not installed!"
        echo ""
        echo "Please install kwokctl using one of the following methods:"
        echo ""
        echo "  macOS/Linux (Homebrew):"
        echo "    brew install kwok"
        echo ""
        echo "  Go install:"
        echo "    go install sigs.k8s.io/kwok/cmd/kwokctl@latest"
        echo ""
        echo "  For more options, visit: https://kwok.sigs.k8s.io/docs/user/installation/"
        exit 1
    fi
    echo_info "kwokctl found: $(kwokctl --version)"
}

# Check if kubectl is installed
check_kubectl() {
    echo_info "Checking if kubectl is installed..."
    if ! command -v kubectl &> /dev/null; then
        echo_error "kubectl is not installed!"
        echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    echo_info "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

# Check if Python is installed
check_python() {
    echo_info "Checking if Python is installed..."
    if ! command -v python3 &> /dev/null; then
        echo_error "Python 3 is not installed!"
        exit 1
    fi
    echo_info "Python found: $(python3 --version)"
}

# Create the KWOK cluster
create_cluster() {
    echo_info "Creating KWOK cluster '${CLUSTER_NAME}'..."
    
    # Check if cluster already exists
    if kwokctl get clusters 2>/dev/null | grep -q "${CLUSTER_NAME}"; then
        echo_warn "Cluster '${CLUSTER_NAME}' already exists."
        read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo_info "Deleting existing cluster..."
            kwokctl delete cluster --name "${CLUSTER_NAME}"
        else
            echo_info "Using existing cluster."
            return 0
        fi
    fi
    
    kwokctl create cluster --name "${CLUSTER_NAME}"
    echo_info "Cluster '${CLUSTER_NAME}' created successfully!"
}

# Generate and apply nodes
setup_nodes() {
    echo_info "Generating node manifests..."
    cd "${SCRIPT_DIR}"
    python3 generate-nodes.py
    
    echo_info "Applying nodes to cluster..."
    kubectl apply -f nodes.yaml
    
    echo_info "Waiting for nodes to be ready..."
    sleep 2
    
    echo ""
    echo_info "Cluster nodes:"
    kubectl get nodes --show-labels
}

# Main execution
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║      In-Depth K8s Scheduling - Setup Script             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_kwokctl
    check_kubectl
    check_python
    
    echo ""
    create_cluster
    
    echo ""
    setup_nodes
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    Setup Complete! 🎉                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Your cluster '${CLUSTER_NAME}' is ready with 30 simulated nodes:"
    echo "  • Nodes 01-10: zone=us-east-1a (standard)"
    echo "  • Nodes 11-20: zone=us-east-1b (standard)"
    echo "  • Nodes 21-25: GPU nodes (tainted)"
    echo "  • Nodes 26-30: production/large"
    echo ""
    echo "To interact with the cluster:"
    echo "  kubectl get nodes"
    echo "  kubectl describe node node-01"
    echo ""
    echo "To delete the cluster when done:"
    echo "  kwokctl delete cluster --name ${CLUSTER_NAME}"
    echo ""
}

main "$@"

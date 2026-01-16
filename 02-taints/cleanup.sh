#!/bin/bash
# Cleanup script for Module 02: Taints and Tolerations

echo "Cleaning up Module 02 (Taints)..."

# Delete deployments
kubectl delete deployment web-app --ignore-not-found
kubectl delete deployment sec-monitor --ignore-not-found
kubectl delete -f ../01-affinity/data-processor-flexible.yaml

# Remove maintenance taints (outage=true:NoExecute)
echo "Removing maintenance taints from all nodes..."
kubectl taint nodes --all outage- 2>/dev/null || true

echo "✓ Module 02 cleanup complete!"

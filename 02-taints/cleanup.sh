#!/bin/bash
# Cleanup script for Module 02: Taints and Tolerations

echo "Cleaning up Module 02 (Taints)..."

# Delete deployments
kubectl delete deployment web-app --ignore-not-found
kubectl delete deployment sec-monitor --ignore-not-found

# Remove production node taints (tier=secure:NoSchedule)
echo "Removing production node taints..."
kubectl taint nodes -l env=production tier- 2>/dev/null || true

# Remove maintenance taints (outage=true:NoExecute)
echo "Removing maintenance taints from all nodes..."
kubectl taint nodes --all outage- 2>/dev/null || true

echo "✓ Module 02 cleanup complete!"

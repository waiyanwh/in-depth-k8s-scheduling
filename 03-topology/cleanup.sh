#!/bin/bash
# Cleanup script for Module 03: Topology Spread Constraints

echo "Cleaning up Module 03 (Topology)..."

kubectl delete deployment payment-gateway --ignore-not-found
kubectl delete deployment legacy-cache --ignore-not-found

echo "✓ Module 03 cleanup complete!"

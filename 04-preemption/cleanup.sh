#!/bin/bash
# Cleanup script for Module 04: Priority and Preemption

echo "Cleaning up Module 04 (Preemption)..."

# Delete deployments
kubectl delete deployment batch-processing --ignore-not-found
kubectl delete deployment realtime-analytics --ignore-not-found

# Delete priority classes
kubectl delete priorityclass low-priority --ignore-not-found
kubectl delete priorityclass high-priority --ignore-not-found

echo "✓ Module 04 cleanup complete!"

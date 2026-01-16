#!/bin/bash
# Cleanup script for Module 01: Node Affinity

echo "Cleaning up Module 01 (Affinity)..."

kubectl delete deployment ai-model-training --ignore-not-found
kubectl delete deployment data-processor --ignore-not-found

echo "✓ Module 01 cleanup complete!"

#!/bin/bash
# Cleanup script for Module 05: Manual Scheduling

echo "Cleaning up Module 05 (Manual Scheduling)..."

kubectl delete pod mystery-pod --ignore-not-found

echo "✓ Module 05 cleanup complete!"

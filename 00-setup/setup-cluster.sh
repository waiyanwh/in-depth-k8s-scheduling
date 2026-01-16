#!/bin/bash
CLUSTER_NAME="scheduling-lab"

# 1. Create Cluster (ignore if exists)
kwokctl get clusters | grep -q $CLUSTER_NAME
if [ $? -ne 0 ]; then
    echo "Creating cluster $CLUSTER_NAME..."
    kwokctl create cluster --name $CLUSTER_NAME
else
    echo "Cluster $CLUSTER_NAME already exists."
fi

# Switch context just in case
kubectl config use-context kwok-$CLUSTER_NAME

# 2. Clean slate: Delete all existing nodes to remove old names
echo "Cleaning up old nodes..."
kubectl delete nodes --all

# 3. Generate and Apply
echo "Generating semantic nodes..."
python3 generate-nodes.py > nodes.yaml

echo "Applying new nodes..."
kubectl apply -f nodes.yaml

echo "✅ Done! Run 'kubectl get nodes' to see your beautiful new names."

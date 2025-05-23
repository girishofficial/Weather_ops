#!/bin/bash

echo "Deploying Filebeat for Weather_ops log collection..."

# Ensure namespace exists
kubectl apply -f kubernetes/namespace.yaml

# Apply RBAC configurations
echo "Setting up RBAC for Filebeat..."
kubectl apply -f kubernetes/filebeat/filebeat-rbac.yaml

# Create persistent volume claim for logs
echo "Creating PVC for logs storage..."
kubectl apply -f kubernetes/filebeat/filebeat-pvc.yaml

# Create ConfigMap with Filebeat configuration
echo "Creating Filebeat configuration..."
kubectl apply -f kubernetes/filebeat/filebeat-config.yaml

# Deploy Filebeat DaemonSet
echo "Deploying Filebeat DaemonSet..."
kubectl apply -f kubernetes/filebeat/filebeat-daemonset.yaml

echo "Waiting for Filebeat pods to be ready..."
kubectl wait --for=condition=Ready pods -l app=filebeat -n weather-ops --timeout=120s

echo "Filebeat deployment complete!"
echo "You can view collected logs with:"
echo "kubectl exec -it -n weather-ops \$(kubectl get pods -n weather-ops -l app=filebeat -o jsonpath='{.items[0].metadata.name}') -- ls -la /mnt/logs"
echo "kubectl exec -it -n weather-ops \$(kubectl get pods -n weather-ops -l app=filebeat -o jsonpath='{.items[0].metadata.name}') -- cat /mnt/logs/weather-ops-logs"
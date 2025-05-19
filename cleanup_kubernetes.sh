#!/bin/bash

echo "Starting cleanup of Weather_ops resources from Kubernetes..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if the namespace exists
if kubectl get namespace weather-ops &> /dev/null; then
    echo "Found weather-ops namespace, cleaning up resources..."

    # Delete all resources in the namespace
    echo "Deleting all deployments..."
    kubectl delete deployments --all -n weather-ops

    echo "Deleting all services..."
    kubectl delete services --all -n weather-ops

    echo "Deleting all pods..."
    kubectl delete pods --all -n weather-ops

    echo "Deleting all daemonsets..."
    kubectl delete daemonsets --all -n weather-ops

    echo "Deleting all statefulsets..."
    kubectl delete statefulsets --all -n weather-ops

    echo "Deleting all configmaps..."
    kubectl delete configmaps --all -n weather-ops

    echo "Deleting all secrets..."
    kubectl delete secrets --all -n weather-ops

    echo "Deleting all persistent volume claims..."
    kubectl delete pvc --all -n weather-ops

    echo "Deleting all horizontal pod autoscalers..."
    kubectl delete hpa --all -n weather-ops
    
    echo "Deleting all service accounts in weather-ops namespace..."
    kubectl delete serviceaccounts --all -n weather-ops
    
    # Delete RBAC resources related to Promtail/Filebeat
    echo "Deleting ClusterRoleBindings for logging agents..."
    kubectl delete clusterrolebinding promtail 2>/dev/null || true
    kubectl delete clusterrolebinding filebeat 2>/dev/null || true
    
    echo "Deleting ClusterRoles for logging agents..."
    kubectl delete clusterrole promtail 2>/dev/null || true
    kubectl delete clusterrole filebeat 2>/dev/null || true
    
    # Finally delete the namespace itself
    echo "Deleting weather-ops namespace..."
    kubectl delete namespace weather-ops

    echo "Waiting for namespace to be fully deleted..."
    kubectl wait --for=delete namespace/weather-ops --timeout=60s 2>/dev/null || true
    
else
    echo "The weather-ops namespace does not exist. Nothing to clean up."
fi

# Clean up any persistent volumes related to the project
echo "Checking for any persistent volumes related to weather-ops..."
VOLUMES=$(kubectl get pv | grep weather-ops | awk '{print $1}')
if [ -n "$VOLUMES" ]; then
    echo "Deleting persistent volumes: $VOLUMES"
    for vol in $VOLUMES; do
        kubectl delete pv $vol
    done
else
    echo "No persistent volumes found for weather-ops."
fi

echo "Cleanup completed successfully!"
echo "You can now run your Jenkins pipeline to deploy Weather_ops with the new logging configuration."
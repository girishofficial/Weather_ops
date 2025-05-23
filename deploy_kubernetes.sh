#!/bin/bash

# deploy_kubernetes.sh - Script to deploy Weather_ops to Kubernetes
# Created: May 15, 2025

set -e  # Exit on error

# Set FORCE_K8S_DEPLOY=1 to force actual deployment in any environment
FORCE_K8S_DEPLOY=${FORCE_K8S_DEPLOY:-0}

echo "Deploying Weather_ops to Kubernetes..."

# Check if we're running in CI environment (Jenkins)
if [ -n "$JENKINS_HOME" ] && [ "$FORCE_K8S_DEPLOY" != "1" ]; then
    echo "Running in Jenkins environment (simulation mode)"
    echo "To force real deployment in Jenkins, set FORCE_K8S_DEPLOY=1"
    echo "Deployment completed successfully (simulated)!"
    exit 0
fi

# Even if in Jenkins, we're now in forced deployment mode or in local environment
if [ -n "$JENKINS_HOME" ]; then
    echo "Running in Jenkins environment with forced deployment mode"
    
    # Check for shared config and set KUBECONFIG if available
    if [ -f /opt/shared-k8s-config/config ]; then
        echo "Using shared Kubernetes configuration..."
        export KUBECONFIG=/opt/shared-k8s-config/config
        chmod 600 $KUBECONFIG
    else
        echo "Shared Kubernetes configuration not found at /opt/shared-k8s-config/config"
        echo "Please run setup_jenkins_k8s.sh to create it"
        exit 1
    fi
    
    # Test kubectl access
    if ! kubectl get nodes &> /dev/null; then
        echo "ERROR: Cannot connect to Kubernetes cluster"
        echo "Make sure Minikube is running with --listen-address=0.0.0.0"
        echo "Run: minikube stop && minikube start --listen-address=0.0.0.0"
        exit 1
    fi
    
    echo "Successfully connected to Kubernetes cluster from Jenkins"
else
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl is not installed. Please install kubectl first."
        exit 1
    fi

    if command -v minikube &> /dev/null; then
        MINIKUBE_STATUS=$(minikube status --format={{.Host}} 2>/dev/null || echo "Not Running")
        if [ "$MINIKUBE_STATUS" != "Running" ]; then
            echo "Starting Minikube..."
            minikube start
        else
            echo "Minikube is already running."
        fi
        
        # Enable ingress addon if not already enabled
        if ! minikube addons list | grep -q "ingress: enabled"; then
            echo "Enabling Ingress addon in Minikube..."
            minikube addons enable ingress
        fi
    fi
fi

echo "Creating namespace..."
kubectl apply -f kubernetes/namespace.yaml

# Check for and clean up any PVs in Released state
echo "Checking for storage resources that need cleanup..."

PV_STATUS=$(kubectl get pv weather-ops-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")if [ "$PV_STATUS" == "Released" ]; then
    echo "Found PV 'weather-ops-pv' in Released state, cleaning up..."
    kubectl delete pv weather-ops-pv
    echo "Waiting for PV deletion to complete..."
    sleep 3
fi

# Deploy persistent volumes first
echo "Deploying persistent storage..."
kubectl apply -f kubernetes/persistent-volume.yaml

# Verify PVC binding
echo "Verifying PVC binding..."
for i in {1..6}; do
    PVC_STATUS=$(kubectl get pvc -n weather-ops weather-ops-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "$PVC_STATUS" == "Bound" ]; then
        echo "PVC 'weather-ops-pvc' successfully bound."
        break
    else
        echo "Waiting for PVC to bind... (attempt $i/6)"
        sleep 5
    fi
done

# Deploy ConfigMap for DVC init script
echo "Deploying ConfigMaps..."
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/dvc-init.yaml

# Deploy backend
echo "Deploying backend..."
kubectl apply -f kubernetes/backend.yaml

# Deploy frontend
echo "Deploying frontend..."
kubectl apply -f kubernetes/frontend.yaml

# Deploy ingress
echo "Deploying ingress..."
kubectl apply -f kubernetes/ingress.yaml

# Deploy Prometheus for monitoring
echo "Deploying Prometheus monitoring..."
kubectl apply -f kubernetes/prometheus/prometheus-configmap.yaml
kubectl apply -f kubernetes/prometheus/prometheus-deployment.yaml
kubectl apply -f kubernetes/prometheus/prometheus-service.yaml

echo "Waiting for pods to be ready..."
kubectl wait --namespace weather-ops --for=condition=ready pod --selector=app=weather-ops --timeout=120s || true

echo "Deployment completed successfully!"

# If using Minikube and not in Jenkins, show access URLs
if [ -z "$JENKINS_HOME" ] && command -v minikube &> /dev/null; then
    MINIKUBE_IP=$(minikube ip)
    echo ""
    echo "To access the application on Minikube:"
    echo "1. Add this entry to your /etc/hosts file:"
    echo "   $MINIKUBE_IP weather-ops.local"
    echo ""
    echo "2. Then access the application at:"
    echo "   Frontend: http://weather-ops.local"
    echo "   Backend API: http://weather-ops.local/api"
    echo ""
    echo "3. Alternatively, use port-forwarding to access the services directly:"
    echo "   kubectl port-forward -n weather-ops svc/frontend 8502:8501"
    echo "   kubectl port-forward -n weather-ops svc/backend 5001:5000"
fi
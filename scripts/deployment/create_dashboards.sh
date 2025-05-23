#!/bin/bash

# Script to create and update Grafana dashboards for Weather_ops
# Usage: ./create_dashboards.sh [1|0]
# 1 = Force deploy, 0 = Simulate

FORCE_K8S_DEPLOY=$1

if [ "$FORCE_K8S_DEPLOY" = "1" ]; then
    echo "Creating Weather_ops dashboards in Grafana..."
    
    # Create dashboard directories if needed
    mkdir -p kubernetes/grafana/dashboards
    
    # Copy the simple-dashboard.json to create the application dashboard if it doesn't exist
    if [ ! -f kubernetes/grafana/dashboards/weather-ops-dashboard.json ]; then
        echo "Application dashboard file is missing, creating it from simple-dashboard.json..."
        
        # Copy from simple-dashboard.json which exists in the project root
        cp simple-dashboard.json kubernetes/grafana/dashboards/weather-ops-dashboard.json
        echo "Created application dashboard from simple-dashboard.json"
    else
        echo "Using existing weather-ops-dashboard.json file"
    fi
    
    # Create dashboard ConfigMap from the application dashboard (which now exists)
    echo "Creating application dashboard ConfigMap..."
    kubectl create configmap weather-ops-dashboard -n weather-ops --from-file=weather-ops-dashboard.json=kubernetes/grafana/dashboards/weather-ops-dashboard.json --dry-run=client -o yaml | kubectl apply -f -
    
    # Create logs dashboard ConfigMap (which already exists in your workspace)
    echo "Creating logs dashboard ConfigMap..."
    kubectl create configmap weather-ops-logs-dashboard -n weather-ops --from-file=weather-ops-logs-dashboard.json=kubernetes/grafana/dashboards/weather-ops-logs-dashboard.json --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply dashboard provider configuration
    echo "Configuring Grafana dashboard provider..."
    kubectl apply -f kubernetes/grafana/grafana-dashboard-provider.yaml
    
    # Restart Grafana to pick up the changes
    kubectl rollout restart deployment/grafana -n weather-ops
    
    echo "Weather_ops dashboards created successfully."
    echo "Access the application dashboard at: http://localhost:3000/d/weather-ops/weather-ops-application-dashboard"
    echo "Access the logs dashboard at: http://localhost:3000/d/weather-ops-logs/weather-ops-logs-dashboard"
    echo "(after setting up port-forwarding)"
    
else
    echo "Simulating dashboard creation..."
    echo "In a real environment, this would:"
    echo "- Create a preconfigured Weather_ops application dashboard"
    echo "- Set up monitoring for HTTP requests, latency, and error rates"
    echo "- Add visualizations for model predictions and training counts"
    echo "- Configure automatic dashboard refresh"
fi
#!/bin/bash
# deploy_logging_infra.sh - Script to deploy logging infrastructure to Kubernetes
# Created: May 23, 2025

set -e  # Exit on error

echo "Deploying logging infrastructure to Kubernetes..."

# Ensure namespace exists
kubectl apply -f kubernetes/namespace.yaml || true

# First deploy Grafana to ensure it exists
echo "Deploying Grafana first..."
kubectl apply -f kubernetes/grafana/grafana-deployment.yaml -f kubernetes/grafana/grafana-service.yaml

# Create Loki deployment
echo "Deploying Loki..."
kubectl apply -f kubernetes/loki/loki-deployment.yaml

# Deploy Promtail with RBAC
echo "Deploying Promtail with proper RBAC..."
kubectl apply -f kubernetes/promtail/promtail-rbac.yaml
kubectl apply -f kubernetes/promtail/promtail-configmap.yaml
kubectl apply -f kubernetes/promtail/promtail-deployment.yaml

# Configure Grafana data sources
echo "Configuring Grafana data sources..."
kubectl apply -f kubernetes/grafana/grafana-datasources.yaml

# Configure Grafana dashboards
echo "Configuring Grafana dashboards..."
kubectl apply -f kubernetes/grafana/grafana-dashboard-provider.yaml

# Create dashboard ConfigMaps using existing JSON files
echo "Creating dashboard ConfigMaps..."
kubectl create configmap weather-ops-dashboard -n weather-ops --from-file=weather-ops-dashboard.json=kubernetes/grafana/dashboards/weather-ops-dashboard.json --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap weather-ops-logs-dashboard -n weather-ops --from-file=weather-ops-logs-dashboard.json=kubernetes/grafana/dashboards/weather-ops-logs-dashboard.json --dry-run=client -o yaml | kubectl apply -f -

# Apply the fixed Grafana deployment that mounts all dashboards
echo "Applying Grafana deployment with dashboards..."
kubectl apply -f kubernetes/grafana/grafana-fixed-deployment.yaml

# Wait before attempting to restart Grafana
echo "Waiting for Grafana deployment to be ready..."
kubectl wait --for=condition=available deployment/grafana -n weather-ops --timeout=60s || true

# Restart Grafana to pick up all changes
echo "Restarting Grafana to pick up all changes..."
kubectl rollout restart deployment/grafana -n weather-ops

echo "Logging infrastructure deployed successfully!"
echo "Access Grafana at http://<cluster-ip>:30080 and navigate to the Dashboards section"
echo "You should see both 'Weather_ops Application Dashboard' and 'Weather_ops Logs Dashboard'"

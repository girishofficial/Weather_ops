#!/bin/bash

echo "Deploying Weather_ops Logging and Monitoring Stack..."

# Ensure namespace exists
kubectl apply -f kubernetes/namespace.yaml

# Deploy Loki for log aggregation
echo "Setting up Loki log aggregation..."
kubectl apply -f kubernetes/loki/loki-deployment.yaml

# Set up Filebeat for log collection
echo "Setting up Filebeat for log collection..."
kubectl apply -f kubernetes/filebeat/filebeat-rbac.yaml
kubectl apply -f kubernetes/filebeat/filebeat-pvc.yaml
kubectl apply -f kubernetes/filebeat/filebeat-config.yaml
kubectl apply -f kubernetes/filebeat/filebeat-daemonset.yaml

# Deploy Grafana with dashboards
echo "Deploying Grafana with pre-configured dashboards..."
kubectl apply -f kubernetes/grafana/grafana-deployment.yaml
kubectl apply -f kubernetes/grafana/grafana-service.yaml

# Wait for deployments to be ready
echo "Waiting for components to be ready..."
kubectl wait --for=condition=Ready pods -l app=loki -n weather-ops --timeout=120s
kubectl wait --for=condition=Ready pods -l app=filebeat -n weather-ops --timeout=120s
kubectl wait --for=condition=Ready pods -l app=grafana -n weather-ops --timeout=120s

echo "Logging and Monitoring Stack deployment complete!"
echo ""
echo "Access Grafana dashboard at: http://cluster-ip:30080"
echo "Login credentials:"
echo "  Username: admin"
echo "  Password: weather-ops-admin"
echo ""
echo "Your Weather_ops logs from both frontend and backend are now visible in Grafana!"
echo "Navigate to the 'Weather_ops System Dashboard' to see your application logs and metrics."
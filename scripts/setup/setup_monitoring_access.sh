#!/bin/bash
# setup_monitoring_access.sh - Script to set up port forwarding for monitoring tools
# Created: May 23, 2025

set -e  # Exit on error

# Kill any existing port-forwarding processes
pkill -f "kubectl port-forward.*prometheus" || true
pkill -f "kubectl port-forward.*grafana" || true

# Start port forwarding for monitoring tools
nohup kubectl port-forward -n weather-ops svc/prometheus-service 9090:9090 > /tmp/prometheus-port-forward.log 2>&1 &
PROMETHEUS_PID=$!
echo "Prometheus port forwarding started on port 9090 (PID: $PROMETHEUS_PID)"

nohup kubectl port-forward -n weather-ops svc/grafana 3000:3000 > /tmp/grafana-port-forward.log 2>&1 &
GRAFANA_PID=$!
echo "Grafana port forwarding started on port 3000 (PID: $GRAFANA_PID)"

# Store the PIDs in a file so they can be terminated later if needed
echo "Prometheus PID: $PROMETHEUS_PID" > /tmp/monitoring_port_forward_pids.txt
echo "Grafana PID: $GRAFANA_PID" >> /tmp/monitoring_port_forward_pids.txt

echo "Port forwarding setup complete!"
echo "Access Prometheus at: http://localhost:9090"
echo "Access Grafana at: http://localhost:3000 (default credentials: admin/WeatherOps2025Secure!)"

# Get Minikube IP for direct NodePort access
MINIKUBE_IP=$(minikube ip)

echo "Monitoring tools are now accessible:"
echo "- Prometheus: http://localhost:9090"
echo "- Grafana via port-forwarding: http://localhost:3000 (default credentials: admin/WeatherOps2025Secure!)"
echo ""
echo "IMPORTANT: For direct access without port-forwarding:"
echo "- Grafana direct access: http://${MINIKUBE_IP}:30080 (default credentials: admin/WeatherOps2025Secure!)"
echo "- You can view the Weather_ops dashboard at: http://${MINIKUBE_IP}:30080/d/weather-ops/weather-ops-application-dashboard"
echo "- You can view the logs dashboard at: http://${MINIKUBE_IP}:30080/d/weather-ops-logs/weather-ops-logs-dashboard"

#!/bin/bash
# deploy_docker_compose.sh - Script to deploy Weather_ops application using Docker Compose
# Created: May 23, 2025

set -e  # Exit on error

# Environment variables expected from Jenkins:
# LATEST_BACKEND_IMAGE - Backend Docker image with tag
# LATEST_FRONTEND_IMAGE - Frontend Docker image with tag

echo "Deploying Weather_ops application using Docker Compose..."

# Create a deployment directory if it doesn't exist
mkdir -p /tmp/weather_ops_deployment

# Create a docker-compose override file for the deployment
cat > /tmp/weather_ops_deployment/docker-compose.yml << EOC
version: '3'
services:
  backend:
    image: ${LATEST_BACKEND_IMAGE}
    ports:
      - "5001:5000"
    environment:
      - ENV=staging
  
  frontend:
    image: ${LATEST_FRONTEND_IMAGE}
    ports:
      - "8502:8501"
    environment:
      - BACKEND_URL=http://backend:5000
    depends_on:
      - backend
EOC

# Print deployment information
echo "Deployment prepared at /tmp/weather_ops_deployment"

# Actually start the containers
cd /tmp/weather_ops_deployment && docker-compose down -v && docker-compose up -d

echo "Containers have been started!"
echo "Frontend available at: http://localhost:8502"
echo "Backend API available at: http://localhost:5001"

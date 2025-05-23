pipeline {
    agent any
    
    parameters {
        booleanParam(name: 'FORCE_K8S_DEPLOY', defaultValue: false, description: 'Force actual deployment to Kubernetes (not simulation)')
    }
    
    environment {
        DOCKER_HUB_CREDS = credentials('dockerhub-login')
        DOCKER_BACKEND_IMAGE = "girish445g/weather-ops-backend:${BUILD_NUMBER}"
        DOCKER_FRONTEND_IMAGE = "girish445g/weather-ops-frontend:${BUILD_NUMBER}"
        LATEST_BACKEND_IMAGE = "girish445g/weather-ops-backend:latest"
        LATEST_FRONTEND_IMAGE = "girish445g/weather-ops-frontend:latest"
        PYTHON_VERSION = "3.12"
        // Set FORCE_K8S_DEPLOY based on parameter
        FORCE_K8S_DEPLOY = "${params.FORCE_K8S_DEPLOY == true ? '1' : '0'}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup Python Environment') {
            steps {
                sh 'echo "Setting up Python environment..."'
                sh 'python${PYTHON_VERSION} -m venv jenkins_venv'
                sh 'jenkins_venv/bin/pip install -r backend/requirements.txt'
                sh 'jenkins_venv/bin/pip install pytest pytest-cov fastapi httpx'
            }
        }
        
        stage('Setup Test Data') {
            steps {
                sh 'echo "Setting up test data..."'
                sh '''
                    # Create data directories if they don't exist
                    mkdir -p data
                    mkdir -p backend/data
                    
                    # Create a sample raw_weather.csv file if it doesn't exist
                    if [ ! -f data/raw_weather.csv ]; then
                        echo "time,tavg,tmin,tmax,prcp,wspd" > data/raw_weather.csv
                        echo "2025-01-01,15.0,10.0,20.0,0.5,10.0" >> data/raw_weather.csv
                        echo "2025-01-02,16.0,11.0,21.0,0.0,12.0" >> data/raw_weather.csv
                        echo "2025-01-03,17.0,12.0,22.0,0.2,11.0" >> data/raw_weather.csv
                    fi
                    
                    # Create a sample cleaned_weather.csv file if it doesn't exist
                    if [ ! -f data/cleaned_weather.csv ]; then
                        echo "time,tavg,tmin,tmax,prcp,wspd" > data/cleaned_weather.csv
                        echo "2025-01-01,15.0,10.0,20.0,0.5,10.0" >> data/cleaned_weather.csv
                        echo "2025-01-02,16.0,11.0,21.0,0.0,12.0" >> data/cleaned_weather.csv
                        echo "2025-01-03,17.0,12.0,22.0,0.2,11.0" >> data/cleaned_weather.csv
                    fi
                    
                    # Copy the data files to the backend directory as well
                    cp -f data/raw_weather.csv backend/data/ || true
                    cp -f data/cleaned_weather.csv backend/data/ || true
                '''
            }
        }
        
        stage('Data Validation') {
            steps {
                sh 'echo "Validating data integrity..."'
                sh '''
                jenkins_venv/bin/python -c "
import pandas as pd
import os

# Check if data files exist
data_paths = ['data/raw_weather.csv', 'data/cleaned_weather.csv']
for path in data_paths:
    if not os.path.exists(path):
        print(f'Error: Data file {path} not found')
        exit(1)

# Validate cleaned data
try:
    df = pd.read_csv('data/cleaned_weather.csv')
    # Check for null values in critical columns
    critical_columns = ['tavg', 'tmin', 'tmax', 'prcp', 'wspd']
    for col in critical_columns:
        if col in df.columns and df[col].isnull().sum() > 0:
            print(f'Warning: {df[col].isnull().sum()} null values found in {col}')
    print('Data validation completed successfully')
except Exception as e:
    print(f'Error during data validation: {str(e)}')
    exit(1)
"
                '''
            }
        }
        
        stage('Test') {
            steps {
                sh 'echo "Running tests..."'
                sh 'jenkins_venv/bin/pytest backend/ -v'
            }
        }
        
        stage('Build Docker Images') {
            steps {
                sh 'docker-compose build'
                // Debug: List all images after build
                sh 'docker images'
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                sh 'echo $DOCKER_HUB_CREDS_PSW | docker login -u $DOCKER_HUB_CREDS_USR --password-stdin'
                
                // Tag and push backend image with build number
                sh 'docker tag weather_ops_backend:latest girish445g/weather-ops-backend:${BUILD_NUMBER}'
                sh 'docker push girish445g/weather-ops-backend:${BUILD_NUMBER}'
                
                // Tag and push backend image as latest
                sh 'docker tag weather_ops_backend:latest girish445g/weather-ops-backend:latest'
                sh 'docker push girish445g/weather-ops-backend:latest'
                
                // Tag and push frontend image with build number
                sh 'docker tag weather_ops_frontend:latest girish445g/weather-ops-frontend:${BUILD_NUMBER}'
                sh 'docker push girish445g/weather-ops-frontend:${BUILD_NUMBER}'
                
                // Tag and push frontend image as latest
                sh 'docker tag weather_ops_frontend:latest girish445g/weather-ops-frontend:latest'
                sh 'docker push girish445g/weather-ops-frontend:latest'
            }
        }
        
        stage('Deploy') {
            steps {
                sh 'echo "Deploying application..."'
                // This simulates a deployment to a staging environment
                sh '''
                    # Create a deployment directory if it doesn't exist
                    mkdir -p /tmp/weather_ops_deployment
                    
                    # Create a docker-compose override file for the deployment
                    cat > /tmp/weather_ops_deployment/docker-compose.yml << EOF
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
EOF
                    
                    # Print deployment information
                    echo "Deployment prepared at /tmp/weather_ops_deployment"
                    
                    # Actually start the containers
                    cd /tmp/weather_ops_deployment && docker-compose down -v && docker-compose up -d
                    
                    echo "Containers have been started!"
                    echo "Frontend available at: http://localhost:8502"
                    echo "Backend API available at: http://localhost:5001"
                '''
            }
        }

        stage('Setup Kubernetes') {
            steps {
                echo 'Setting up Kubernetes environment...'
                sh '''
                    # Install kubectl if not present
                    if ! command -v kubectl &> /dev/null; then
                        echo "Installing kubectl..."
                        # Create a bin directory in Jenkins home
                        mkdir -p $HOME/bin
                        
                        # Try apt installation if we have sudo without password
                        if command -v apt-get &> /dev/null && sudo -n true 2>/dev/null; then
                            sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg
                            curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
                            echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
                            sudo apt-get update && sudo apt-get install -y kubectl
                        else
                            # Fall back to direct download if apt is not available or sudo needs password
                            KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
                            echo "Downloading kubectl version ${KUBECTL_VERSION}..."
                            curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
                            chmod +x kubectl
                            mv kubectl $HOME/bin/
                            export PATH=$HOME/bin:$PATH
                            echo "kubectl installed at $HOME/bin/kubectl"
                        fi
                    else
                        echo "kubectl is already installed at $(which kubectl)"
                        kubectl version --client
                    fi
                    
                    # Add $HOME/bin to PATH permanently for this job
                    echo "export PATH=$HOME/bin:$PATH" >> $HOME/.bashrc
                    
                    # Setup kubeconfig directory
                    mkdir -p ~/.kube
                    
                    # Use shared Kubernetes config if available
                    if [ -f /opt/shared-k8s-config/config ]; then
                        echo "Using shared Kubernetes configuration..."
                        cp /opt/shared-k8s-config/config ~/.kube/config
                        chmod 600 ~/.kube/config
                        
                        # Update paths in config to use shared Minikube certs
                        sed -i "s|$HOME/.minikube|/opt/shared-k8s-config/.minikube|g" ~/.kube/config
                    else
                        echo "WARNING: Shared Kubernetes configuration not found!"
                        echo "Run these commands on the host machine to set it up:"
                        echo "sudo mkdir -p /opt/shared-k8s-config"
                        echo "sudo cp ~/.kube/config /opt/shared-k8s-config/"
                        echo "sudo cp -r ~/.minikube /opt/shared-k8s-config/"
                        echo "sudo chown -R jenkins:jenkins /opt/shared-k8s-config"
                        echo "sudo chmod -R 755 /opt/shared-k8s-config"
                    fi
                    
                    # Make deployment script executable
                    chmod +x ./deploy_kubernetes.sh
                '''
            }
        }

        stage('Kubernetes Deployment') {
            steps {
                echo 'Deploying to Kubernetes...'
                sh '''
                if [ "$FORCE_K8S_DEPLOY" = "1" ]; then
                    echo "Forcing actual deployment to Kubernetes..."
                    ./deploy_kubernetes.sh
                else
                    echo "Simulating Kubernetes deployment..."
                    echo "This is a simulated Kubernetes deployment environment."
                    echo "In a real deployment, Weather_ops would be deployed to a Kubernetes cluster with:"
                    echo "- Backend deployment (machine learning API)"
                    echo "- Frontend deployment (Streamlit UI)"
                    echo "- Persistent storage for weather data and models"
                    echo "- ConfigMaps for configuration"
                    echo "- Services for networking"
                    echo "- Ingress for external access"
                fi
                '''
            }
        }
        
        stage('Apply Kubernetes HPA') {
            steps {
                echo 'Applying backend HPA manifest to Kubernetes...'
                sh '''
                if [ "$FORCE_K8S_DEPLOY" = "1" ]; then
                    kubectl apply -f kubernetes/backend-hpa.yaml
                else
                    echo "Simulating HPA application..."
                    echo "In a real environment, this would configure horizontal pod autoscaling"
                    echo "to automatically scale the backend based on CPU usage."
                fi
                '''
            }
        }
        
        stage('Deploy Prometheus Monitoring') {
            steps {
                echo 'Setting up Prometheus monitoring...'
                sh '''
                if [ "$FORCE_K8S_DEPLOY" = "1" ]; then
                    echo "Deploying Prometheus to Kubernetes..."
                    
                    # Apply the Prometheus configurations from manifest files
                    kubectl apply -f kubernetes/prometheus/prometheus-configmap.yaml
                    kubectl apply -f kubernetes/prometheus/prometheus-deployment.yaml
                    kubectl apply -f kubernetes/prometheus/prometheus-service.yaml
                    
                    echo "Prometheus deployed successfully."
                    echo "You can access the Prometheus dashboard at http://$(minikube ip):30090"
                else
                    echo "Simulating Prometheus deployment..."
                    echo "In a real environment, this would deploy Prometheus for monitoring:"
                    echo "- Backend API metrics (request count, latency)"
                    echo "- Model training and prediction counts"
                    echo "- System metrics (CPU, memory usage)"
                    echo "- Kubernetes metrics"
                fi
                '''
            }
        }
        
        stage('Deploy Logging Infrastructure') {
            steps {
                echo 'Setting up logging infrastructure with Loki and Promtail...'
                sh '''
                if [ "$FORCE_K8S_DEPLOY" = "1" ]; then
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
                else
                    echo "Simulating logging infrastructure deployment..."
                    echo "In a real environment, this would:"
                    echo "- Deploy Loki as a log aggregation backend"
                    echo "- Configure Promtail to process and forward logs to Loki"
                    echo "- Set up Grafana dashboards for log visualization"
                    echo "- Allow filtering logs by component (frontend/backend) and searching for specific patterns"
                fi
                '''
            }
        }
        
        stage('Deploy Grafana Dashboard') {
            steps {
                echo 'Setting up Grafana dashboards...'
                sh '''
                if [ "$FORCE_K8S_DEPLOY" = "1" ]; then
                    echo "Deploying Grafana to Kubernetes..."
                    
                    # Apply the Grafana configuration files
                    kubectl apply -f kubernetes/grafana/grafana-datasources.yaml
                    kubectl apply -f kubernetes/grafana/grafana-deployment.yaml
                    kubectl apply -f kubernetes/grafana/grafana-service.yaml
                    
                    echo "Grafana deployed successfully."
                    echo "You can access the Grafana dashboard directly via NodePort at:"
                    echo "http://$(minikube ip):30080"
                    echo "Default credentials: admin/admin"
                    
                    # Wait for Grafana to be ready
                    echo "Waiting for Grafana pod to be ready..."
                    kubectl wait --namespace weather-ops --for=condition=ready pod --selector=app=grafana --timeout=120s || echo "Grafana pod not ready in time, may still be starting"
                    
                else
                    echo "Simulating Grafana deployment..."
                    echo "In a real environment, this would deploy Grafana with:"
                    echo "- Prometheus datasource pre-configured"
                    echo "- Dashboards for Weather_ops application metrics"
                    echo "- Custom dashboards for model performance monitoring"
                    echo "- Alerts for critical performance issues"
                fi
                '''
            }
        }
        
        stage('Create Weather_ops Dashboard') {
            steps {
                echo 'Creating custom dashboards for Weather_ops...'
                sh '''
                # Make the dashboard creation script executable
                chmod +x ./create_dashboards.sh
                # Execute the script passing the FORCE_K8S_DEPLOY parameter
                ./create_dashboards.sh $FORCE_K8S_DEPLOY
                '''
            }
        }

        stage('Setup Monitoring Access') {
            steps {
                echo 'Setting up persistent access to monitoring tools...'
                sh '''
                if [ "$FORCE_K8S_DEPLOY" = "1" ]; then
                    # Kill any existing port-forwarding processes
                    pkill -f "kubectl port-forward.*prometheus" || true
                    pkill -f "kubectl port-forward.*grafana" || true
                    
                    # Create a simple script to maintain port forwarding
                    cat > /tmp/monitoring_port_forward.sh << 'EOF'
#!/bin/bash
# Start port forwarding for monitoring tools
nohup kubectl port-forward -n weather-ops svc/prometheus-service 9090:9090 > /tmp/prometheus-port-forward.log 2>&1 &
echo "Prometheus port forwarding started on port 9090"
nohup kubectl port-forward -n weather-ops svc/grafana 3000:3000 > /tmp/grafana-port-forward.log 2>&1 &
echo "Grafana port forwarding started on port 3000"

# Store the PIDs in a file so they can be terminated later if needed
echo "Prometheus PID: $!" > /tmp/monitoring_port_forward_pids.txt
echo "Grafana PID: $!" >> /tmp/monitoring_port_forward_pids.txt

echo "Port forwarding setup complete!"
echo "Access Prometheus at: http://localhost:9090"
echo "Access Grafana at: http://localhost:3000 (default credentials: admin/WeatherOps2025Secure!)"
EOF
                    
                    # Make the script executable
                    chmod +x /tmp/monitoring_port_forward.sh
                    
                    # Execute the port forwarding script
                    /tmp/monitoring_port_forward.sh
                    
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
                else
                    echo "Simulating monitoring access setup..."
                    echo "In a real environment, this would set up persistent port forwarding for:"
                    echo "- Prometheus: http://localhost:9090"
                    echo "- Grafana: http://localhost:3000"
                fi
                '''
            }
        }
    }
    
    post {
        always {
            sh 'docker logout'
            sh 'if [ -d "jenkins_venv" ]; then rm -rf jenkins_venv; fi'
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Please check the logs for details.'
        }
    }
}
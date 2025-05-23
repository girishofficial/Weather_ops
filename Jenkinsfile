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
                # Make the validation script executable
                chmod +x ./validate_data.py
                
                # Execute the validation script using the Jenkins virtual environment
                jenkins_venv/bin/python ./validate_data.py
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
                sh '''
                    # Make the deployment script executable
                    chmod +x ./deploy_docker_compose.sh
                    # Execute the script to deploy using Docker Compose
                    ./deploy_docker_compose.sh
                '''
            }
        }

        stage('Setup Kubernetes') {
            steps {
                echo 'Setting up Kubernetes environment...'
                sh '''
                    # Make the Kubernetes setup script executable
                    chmod +x ./setup_kubernetes_env.sh
                    
                    # Execute the script to setup Kubernetes environment
                    ./setup_kubernetes_env.sh
                    
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
                    # Make the logging infrastructure script executable
                    chmod +x ./deploy_logging_infra.sh
                    # Execute the script to deploy logging infrastructure
                    ./deploy_logging_infra.sh
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
                    # Make the monitoring access script executable
                    chmod +x ./setup_monitoring_access.sh
                    # Execute the script to setup monitoring access
                    ./setup_monitoring_access.sh
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
#!/bin/bash
# setup_kubernetes_env.sh - Script to set up Kubernetes environment for Jenkins
# Created: May 23, 2025

set -e  # Exit on error

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

echo "Kubernetes environment setup complete!"

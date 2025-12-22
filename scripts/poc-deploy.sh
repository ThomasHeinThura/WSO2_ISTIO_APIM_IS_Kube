#!/bin/bash

# POC Deployment Script for WSO2 APIM + IS on Kind with Istio
# Run from WSO2_ISTIO_APIM_IS_Kube directory

set -e

CLUSTER_NAME="wso2-poc"
ISTIO_PROFILE="demo"

echo "Starting POC deployment..."

# 1. Create Kind cluster
echo "Creating Kind cluster..."
kind create cluster --name $CLUSTER_NAME --image kindest/node:v1.27.6
kubectl cluster-info --context kind-$CLUSTER_NAME

# 2. Install Istio
echo "Installing Istio..."
istioctl install --set profile=$ISTIO_PROFILE -y
kubectl label namespace default istio-injection=enabled --overwrite

# 3. Create namespaces
echo "Creating namespaces..."
kubectl create ns apim --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns apk --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns is --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns apim istio-injection=enabled
kubectl label ns apk istio-injection=enabled
kubectl label ns is istio-injection=enabled

# 4. Deploy APIM
echo "Deploying WSO2 APIM..."
helm repo add wso2 https://helm.wso2.com
helm repo update
helm install apim wso2/wso2am -n apim -f values-poc-apim.yaml

# 5. Deploy IS
echo "Deploying WSO2 IS..."
# Assume kubernetes-is is cloned at workspace root
if [ ! -d "../../kubernetes-is" ]; then
    echo "Cloning kubernetes-is..."
    git clone https://github.com/wso2/kubernetes-is.git ../../kubernetes-is
fi
helm install is ../../kubernetes-is/helm/is -n is -f values-poc-is.yaml

# 6. Wait for deployments
echo "Waiting for deployments..."
kubectl wait --for=condition=available --timeout=300s deployment -n apim
kubectl wait --for=condition=available --timeout=300s deployment -n is

# 7. Apply Istio Gateway and VirtualServices
echo "Applying Istio Gateway and VirtualServices..."
kubectl apply -f istio-gateway.yaml

echo "POC deployment complete!"
echo "Access points:"
echo "- APIM Gateway: http://apim.local"
echo "- IS: http://is.local"
echo ""
echo "Add to /etc/hosts:"
echo "127.0.0.1 apim.local is.local"
echo ""
echo "Port forward Istio ingress if needed:"
echo "kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
#!/bin/bash
set -e

echo "Deploying MySQL..."

# Create ConfigMap for initialization scripts
# We use --dry-run to allow idempotency (apply -f -)
kubectl create configmap mysql-init-scripts \
  --from-file=../mysql-scripts \
  -n wso2 \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply MySQL Deployment and Service
kubectl apply -f ../mysql.yaml

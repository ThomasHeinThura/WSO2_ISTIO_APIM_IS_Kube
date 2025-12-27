#!/bin/bash
set -e

echo "Deploying MySQL..."

# Create ConfigMap for initialization scripts
# NOTE: Avoid `kubectl apply` here because it stores a huge "last applied" annotation
# and can exceed the 256KB annotation limit when SQL scripts grow.
kubectl delete configmap mysql-init-scripts -n wso2 --ignore-not-found
kubectl create configmap mysql-init-scripts \
  --from-file=mysql-scripts \
  -n wso2

# Apply MySQL Deployment and Service
kubectl apply -f mysql.yaml -n wso2

#!/usr/bin/env bash
set -euo pipefail

# Generic helper for large secrets/configmaps:
# avoids `kubectl apply` "last-applied" annotations which can exceed 256KB.

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <kind: secret|configmap> <name> <namespace> [--from-file=... ...]"
  exit 1
fi

KIND=$1
NAME=$2
NAMESPACE=$3
shift 3

kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"

kubectl delete "${KIND}" "${NAME}" -n "${NAMESPACE}" --ignore-not-found
kubectl create "${KIND}" "${NAME}" -n "${NAMESPACE}" "$@"

echo "Recreated ${KIND}/${NAME} in namespace ${NAMESPACE}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

CLUSTER_NAME=${CLUSTER_NAME:-kind}

# When true, pushes images to the registry (e.g., Docker Hub).
PUSH_IMAGES=${PUSH_IMAGES:-true}
# When true, loads images into the Kind nodes.
LOAD_TO_KIND=${LOAD_TO_KIND:-false}

CP_IMAGE=${CP_IMAGE:-bimdevops/wso2-apim-cp.4.6.0-mysql:latest}
GW_IMAGE=${GW_IMAGE:-bimdevops/wso2-apim-gw.4.6.0-mysql:latest}

CP_BASE_IMAGE=${CP_BASE_IMAGE:-wso2/wso2am:4.6.0}
GW_BASE_IMAGE=${GW_BASE_IMAGE:-docker.wso2.com/wso2am-universal-gw:4.6.0.0}

echo "Building APIM CP image: ${CP_IMAGE}"
docker build \
  -f "${ROOT_DIR}/images/apim-cp/Dockerfile" \
  --build-arg BASE_IMAGE="${CP_BASE_IMAGE}" \
  -t "${CP_IMAGE}" \
  "${ROOT_DIR}"

echo "Building APIM Universal GW image: ${GW_IMAGE}"
docker build \
  -f "${ROOT_DIR}/images/apim-gw/Dockerfile" \
  --build-arg BASE_IMAGE="${GW_BASE_IMAGE}" \
  -t "${GW_IMAGE}" \
  "${ROOT_DIR}"

if [[ "${PUSH_IMAGES}" == "true" ]]; then
  echo "Pushing images (ensure you ran: docker login)"
  docker push "${CP_IMAGE}"
  docker push "${GW_IMAGE}"
fi

if [[ "${LOAD_TO_KIND}" == "true" ]]; then
  echo "Loading images into Kind cluster: ${CLUSTER_NAME}"
  kind load docker-image --name "${CLUSTER_NAME}" "${CP_IMAGE}"
  kind load docker-image --name "${CLUSTER_NAME}" "${GW_IMAGE}"
fi

echo "Done. Built images:"
echo "- ${CP_IMAGE}"
echo "- ${GW_IMAGE}"

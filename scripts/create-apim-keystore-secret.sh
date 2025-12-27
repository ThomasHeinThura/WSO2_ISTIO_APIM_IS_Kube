#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

NAMESPACE=${NAMESPACE:-wso2}
SECRET_NAME=${SECRET_NAME:-apim-keystore-secret}

APIM_ZIP=${APIM_ZIP:-${ROOT_DIR}/Reference/wso2am-4.6.0.zip}

JKS_DIR=${JKS_DIR:-${ROOT_DIR}/Reference}

wso2carbon_jks="${JKS_DIR}/wso2carbon.jks"
truststore_jks="${JKS_DIR}/client-truststore.jks"

if [[ -f "${wso2carbon_jks}" && -f "${truststore_jks}" ]]; then
  echo "Using JKS files from ${JKS_DIR}"
else
  echo "JKS files not found in ${JKS_DIR}; falling back to extracting from ${APIM_ZIP}"

  if [[ ! -f "${APIM_ZIP}" ]]; then
    echo "ERROR: APIM_ZIP not found at ${APIM_ZIP}"
    echo "Download it first (example):"
    echo "  cd ${ROOT_DIR}/Reference && wget https://github.com/wso2/product-apim/releases/download/v4.6.0/wso2am-4.6.0.zip"
    exit 1
  fi

  tmp_dir=$(mktemp -d)
  cleanup() { rm -rf "${tmp_dir}"; }
  trap cleanup EXIT

  unzip -q "${APIM_ZIP}" -d "${tmp_dir}"

  # In the APIM product pack, keystores are under repository/resources/security
  security_dir=$(find "${tmp_dir}" -type d -path "*/repository/resources/security" | head -n 1)
  if [[ -z "${security_dir}" ]]; then
    echo "ERROR: Could not find repository/resources/security inside ${APIM_ZIP}"
    exit 1
  fi

  wso2carbon_jks="${security_dir}/wso2carbon.jks"
  truststore_jks="${security_dir}/client-truststore.jks"

  if [[ ! -f "${wso2carbon_jks}" || ! -f "${truststore_jks}" ]]; then
    echo "ERROR: Missing expected JKS files in ${security_dir}"
    echo "Expected: ${wso2carbon_jks} and ${truststore_jks}"
    exit 1
  fi
fi

kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"

kubectl delete secret "${SECRET_NAME}" -n "${NAMESPACE}" --ignore-not-found
kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
  --from-file=wso2carbon.jks="${wso2carbon_jks}" \
  --from-file=client-truststore.jks="${truststore_jks}"

echo "Created/updated secret ${SECRET_NAME} in namespace ${NAMESPACE}"

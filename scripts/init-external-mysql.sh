#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

DB_HOST=${DB_HOST:-wso2sql.orb.local}
DB_PORT=${DB_PORT:-3306}
DB_USER=${DB_USER:-root}
DB_PASSWORD=${DB_PASSWORD:-}

INCLUDE_IS=${INCLUDE_IS:-false}

usage() {
  cat <<EOF
Initializes WSO2 APIM/IS databases on an external MySQL instance using the SQL in WSO2_ISTIO_APIM_IS_Kube/mysql-scripts.

Env vars:
  DB_HOST       (default: wso2sql.orb.local)
  DB_PORT       (default: 3306)
  DB_USER       (default: root)
  DB_PASSWORD   (required)
  INCLUDE_IS    (default: false)  # when true, also creates IS DBs

Examples:
  DB_PASSWORD='1qaz!QAZ' ./WSO2_ISTIO_APIM_IS_Kube/scripts/init-external-mysql.sh
  DB_PASSWORD='1qaz!QAZ' INCLUDE_IS=true ./WSO2_ISTIO_APIM_IS_Kube/scripts/init-external-mysql.sh
EOF
}

if [[ -z "${DB_PASSWORD}" ]]; then
  echo "ERROR: DB_PASSWORD is required"
  usage
  exit 1
fi

SCRIPTS=(
  "10_apim_db.sql"
  "11_apim_shared_db.sql"
)

if [[ "${INCLUDE_IS}" == "true" ]]; then
  SCRIPTS+=("20_is_identity_db.sql" "21_is_shared_db.sql")
fi

echo "Initializing MySQL on ${DB_HOST}:${DB_PORT} as ${DB_USER}"

echo "Using dockerized mysql client (mysql:8)"
for script in "${SCRIPTS[@]}"; do
  echo "Applying ${script}"
  docker run --rm \
    -e MYSQL_PWD="${DB_PASSWORD}" \
    -v "${ROOT_DIR}/mysql-scripts:/scripts:ro" \
    mysql:8 \
    sh -c "mysql -h '${DB_HOST}' -P '${DB_PORT}' -u '${DB_USER}' < '/scripts/${script}'"
done

echo "Done. Databases and user grants created by the scripts."

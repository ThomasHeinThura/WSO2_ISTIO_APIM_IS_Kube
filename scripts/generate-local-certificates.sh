#!/bin/bash
# Generate self-signed certificates for *.local domains
# Creates: CA cert, server cert, JKS keystores, and updates truststore

set -e

DOMAIN="*.local"
PASSWORD="wso2carbon"
OUTPUT_DIR="./certificates"

mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "Generating CA private key..."
openssl genrsa -out ca.key 2048

echo "Generating CA certificate..."
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=US/ST=CA/L=Mountain View/O=WSO2/OU=WSO2/CN=WSO2 Local CA"

echo "Generating server private key..."
openssl genrsa -out server.key 2048

echo "Generating server certificate signing request..."
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=CA/L=Mountain View/O=WSO2/OU=WSO2/CN=*.local" \
  -addext "subjectAltName = DNS:*.local,DNS:localhost,DNS:apim.local,DNS:gw.local,DNS:websocket.local,DNS:websub.local"

echo "Signing server certificate with CA..."
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 3650 -sha256 \
  -extfile <(printf "subjectAltName = DNS:*.local,DNS:localhost,DNS:apim.local,DNS:gw.local,DNS:websocket.local,DNS:websub.local")

echo "Creating PKCS12 keystore..."
openssl pkcs12 -export -in server.crt -inkey server.key -out server.p12 \
  -name wso2carbon -password pass:"$PASSWORD"

# ------------------------------------------------------------------------------
# Update JKS files (preserving existing content if possible)
# ------------------------------------------------------------------------------

REFERENCE_DIR="../Reference"

# 1. Prepare wso2carbon.jks
if [ -f "$REFERENCE_DIR/wso2carbon.jks" ]; then
    echo "Copying default wso2carbon.jks from Reference..."
    cp "$REFERENCE_DIR/wso2carbon.jks" .
    
    echo "Removing existing 'wso2carbon' alias from wso2carbon.jks..."
    # Ignore error if alias doesn't exist
    keytool -delete -alias wso2carbon -keystore wso2carbon.jks -storepass "$PASSWORD" || true
else
    echo "Default wso2carbon.jks not found in Reference. Creating new one."
fi

echo "Importing new key pair into wso2carbon.jks..."
keytool -importkeystore -deststorepass "$PASSWORD" -destkeypass "$PASSWORD" \
  -destkeystore wso2carbon.jks -srckeystore server.p12 -srcstoretype PKCS12 \
  -srcstorepass "$PASSWORD" -alias wso2carbon

echo "Ensuring 'gateway_certificate_alias' key pair exists in wso2carbon.jks..."
# Ignore error if alias doesn't exist
keytool -delete -alias gateway_certificate_alias -keystore wso2carbon.jks -storepass "$PASSWORD" || true

# Import the same keypair under the alias expected by APIM Gateway for Internal-Key JWT verification
keytool -importkeystore -deststorepass "$PASSWORD" -destkeypass "$PASSWORD" \
  -destkeystore wso2carbon.jks -srckeystore server.p12 -srcstoretype PKCS12 \
  -srcstorepass "$PASSWORD" -srcalias wso2carbon -destalias gateway_certificate_alias

# 2. Prepare client-truststore.jks
if [ -f "$REFERENCE_DIR/client-truststore.jks" ]; then
    echo "Copying default client-truststore.jks from Reference..."
    cp "$REFERENCE_DIR/client-truststore.jks" .
else
    echo "Default client-truststore.jks not found. Creating new one."
fi

echo "Importing CA certificate into client-truststore.jks..."
# Remove old alias if exists to avoid error
keytool -delete -alias wso2localca -keystore client-truststore.jks -storepass "$PASSWORD" || true

keytool -import -trustcacerts -file ca.crt -alias wso2localca \
  -keystore client-truststore.jks -storepass "$PASSWORD" -noprompt

echo "Certificates generated and keystores updated successfully!"
echo ""
echo "Files created:"
echo "  ca.crt - CA certificate"
echo "  ca.key - CA private key"
echo "  server.crt - Server certificate"
echo "  server.key - Server private key"
echo "  wso2carbon.jks - Server keystore (password: $PASSWORD)"
echo "  client-truststore.jks - Client truststore (password: $PASSWORD)"
echo ""
echo "Next steps:"
echo "1. Update the apim-keystore-secret with the new JKS files"
echo "2. Restart WSO2 pods to pick up new certificates"
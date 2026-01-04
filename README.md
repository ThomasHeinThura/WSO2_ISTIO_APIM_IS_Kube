# WSO2 APIM 4.6.0 (Control Plane + Universal Gateway) on Kind + Istio

This repo provides a repeatable setup for APIM 4.6.0 **Control Plane (All-in-One)** + **Universal Gateway** on a local Kind cluster, exposed via **Istio Ingress Gateway**.

Two DB options are supported:

1) **Kubernetes DB** (MySQL runs inside the cluster)
2) **External DB** (you bring your own MySQL)

## Prerequisites

- Docker
- Kind
- kubectl
- Helm
- istioctl
- OpenSSL + Java `keytool` (for generating local certificates)

## Common steps (both DB options)

### 1) Create Kind cluster

```bash
kind create cluster --name wso2-cluster --config Kubernetes_cluster/kind.yaml
```

### 2) Install MetalLB (required on Kind for stable LoadBalancer IPs)

If your Kubernetes already provides LoadBalancer IPs, you can skip this.

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl apply -f metal-ippool.yaml
```

### 3) Install Istio (includes ingress gateway)

```bash
istioctl install -y
```

Wait for a LoadBalancer IP:

```bash
kubectl -n istio-system get svc istio-ingressgateway -w
```

### 4) Create namespace and enable sidecar injection

```bash
kubectl create ns wso2 --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns wso2 istio-injection=enabled --overwrite
```

### 5) Generate local certificates

This creates `certificates/server.crt` + `certificates/server.key` for `*.local` and also produces the JKS files used by APIM.

```bash
./scripts/generate-local-certificates.sh
```

### 6) Create secrets (APIM keystore + Istio ingress TLS)

Create/update the APIM keystore secret (namespace `wso2`):

```bash
kubectl -n wso2 create secret generic apim-keystore-secret \
  --from-file=wso2carbon.jks=certificates/wso2carbon.jks \
  --from-file=client-truststore.jks=certificates/client-truststore.jks \
  --dry-run=client -o yaml | kubectl apply -f -
```

Create/update the Istio Ingress Gateway TLS secret (namespace `istio-system`).

This **must** exist because [istio-gateway.yaml](istio-gateway.yaml) uses `credentialName: wso2-ingress-cert`. If you skip this, `curl` to `https://gw.local` will typically fail with `Recv failure: Connection reset by peer`.

```bash
kubectl -n istio-system create secret tls wso2-ingress-cert \
  --cert=certificates/server.crt \
  --key=certificates/server.key \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n istio-system rollout restart deploy/istio-ingressgateway
kubectl -n istio-system rollout status deploy/istio-ingressgateway
```

Alternative (not recommended if you want `*.local` certs): you can create the APIM keystore secret from the product-pack keystores via:

```bash
./scripts/create-apim-keystore-secret.sh
```

### 7) Build APIM images (MySQL JDBC included) and load into Kind

```bash
LOAD_TO_KIND=true ./scripts/build-apim-images.sh
```

## Option 1: Installation with Kubernetes DB (in-cluster MySQL)

### 1) Deploy MySQL to the cluster

```bash
./scripts/deploy-mysql.sh
```

Wait for MySQL:

```bash
kubectl get pods -n wso2 -l app=mysql -w
```

### 2) Install APIM Control Plane + Universal Gateway

```bash
helm repo add wso2 https://helm.wso2.com
helm repo update

helm install apim wso2/wso2am-all-in-one \
  --version 4.6.0-1 \
  -n wso2 \
  -f apim-cp-values.yaml

helm install apim-gw wso2/wso2am-universal-gw \
  --version 4.6.0-1 \
  -n wso2 \
  -f apim-gw-values.yaml
```

## Option 2: Installation with external DB (external MySQL)

### 1) Initialize schemas on the external DB

This uses the SQL in `mysql-scripts/`.

```bash
DB_PASSWORD='<mysql-root-password>' \
  ./scripts/init-external-mysql.sh
```

### 2) Ensure values files point to the external DB

- Update the DB host/port/user/password in:
  - `apim-cp-values.yaml`
  - `apim-gw-values.yaml`

Important: if a JDBC URL is rendered into XML, keep it XML-safe (escape `&` as `&amp;`).

### 3) Install APIM Control Plane + Universal Gateway

Same Helm commands as Option 1.

## Istio external access (gw.local / apim.local)

### 1) Apply Istio Gateway + VirtualServices

```bash
kubectl apply -f istio-gateway.yaml
```

Verify:

```bash
kubectl get gateways.networking.istio.io -A
kubectl get virtualservice -n wso2
```

### 2) /etc/hosts

With MetalLB providing an external IP, update `/etc/hosts` to point to the LoadBalancer IP:

```bash
# Get the external IP
kubectl get svc -n istio-system istio-ingressgateway

# Add to /etc/hosts (replace with actual EXTERNAL-IP)
192.168.228.240 gw.local apim.local

# (Optional) if you use websocket/websub ingress
# 192.168.228.240 websocket.local websub.local
```

### 3) URLs

- APIM Publisher/DevPortal/Admin: `https://apim.local/`
- Gateway: `https://gw.local/`

**Note**: The setup uses self-signed certificates with `CN=*.local`. Browsers will show certificate warnings, but the certificates are valid for local development.

## Quick status checks

```bash
kubectl get pods -n wso2
kubectl get svc -n wso2
kubectl get pods -n istio-system
```

## Verify (Istio)

```bash
curl -vk https://gw.local/
curl -vk https://apim.local/
```

## API invocation notes

- For API invocation you must publish/deploy an API to the Gateway from APIM.
- If you are using an Internal Key JWT, send it using the `Internal-Key` header.
- If you are using an OAuth2 access token, send it using `Authorization: Bearer <ACCESS_TOKEN>`.

Example:

```bash
curl -vk 'https://gw.local/pizzashack/1.0.0/menu' \
  -H 'Internal-Key: <INTERNAL_KEY_JWT>'
```

## Post-install: Update JWKS Endpoint (Resident Key Manager)

By default, the JWKS endpoint in the Resident Key Manager can point to an **external-facing** hostname. In a local cluster this is sometimes not routable from other pods, and token validation may fail.

Update it to the API Manager **internal service DNS name**:

1) Log into the Admin Portal (this repo’s default hostname):
  - `https://apim.local/admin/`
2) Navigate to **Key Managers** → **Resident Key Manager**.
3) In **Certificates**, change **JWKS URL** to:
  - `https://apim-wso2am-all-in-one-am-service:9443/oauth2/jwks`

Notes:
- The service name above matches the Helm release name `apim` used in this README.
- If you installed with a different release name, adjust the service name accordingly.

### Troubleshooting

- **TLS reset (`curl: (35) Recv failure: Connection reset by peer`)**: create the Istio TLS secret `wso2-ingress-cert` in `istio-system` and restart `istio-ingressgateway`.
- **302 redirect to `https://localhost/carbon/admin/login.jsp`**: usually means you hit the Control Plane webapp or an incorrect host mapping. Confirm you are calling `gw.local`, and `/etc/hosts` points `gw.local` to the Istio ingress IP.
- **401 / invalid_token / Missing Credentials**: token missing/expired or header type mismatch (`Internal-Key` vs `Authorization`).

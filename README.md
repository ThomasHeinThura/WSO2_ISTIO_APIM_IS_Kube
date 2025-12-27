# WSO2 APIM 4.6.0 + WSO2 APK 1.3.0 on Kind + Istio

This repo provides a repeatable local setup for:

- WSO2 APIM 4.6.0 Control Plane (all-in-one)
- WSO2 Universal Gateway (optional)
- WSO2 APK 1.3.0-1
- APIM → APK Agent (CP→DP sync)

Hostnames used by this repo:

- `apim.local` (APIM Control Plane via Istio)
- `gw.local` (Universal Gateway via Istio)
- `api.local` (APK data-plane hostname used by APIM environment label `Default_apk`)

## Prerequisites

- Docker
- kind
- kubectl
- Helm
- istioctl

## Common steps (both DB options)

### 1) Create Kind cluster

```bash
kind create cluster --name wso2-cluster --config Kubernetes_cluster/kind.yaml
```

### 2) Install Istio (includes ingress gateway)

```bash
istioctl install -y
```

### 3) Create namespace and enable sidecar injection

```bash
kubectl create ns wso2 --dry-run=client -o yaml | kubectl apply -f -
kubectl label ns wso2 istio-injection=enabled --overwrite
```

### 4) Create APIM keystore secret

```bash
# Generate *.local certificates
./scripts/generate-local-certificates.sh

# Create the keystore secret
kubectl create secret generic apim-keystore-secret \
  --from-file=wso2carbon.jks=./certificates/wso2carbon.jks \
  --from-file=client-truststore.jks=./certificates/client-truststore.jks \
  -n wso2
```

### 5) Build APIM images (MySQL JDBC included) and load into Kind

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

helm upgrade --install apim wso2/wso2am-all-in-one \
  --version 4.6.0-1 \
  -n wso2 \
  -f apim-cp-values.yaml

helm upgrade --install apim-gw wso2/wso2am-universal-gw \
  --version 4.6.0-1 \
  -n wso2 \
  -f apim-gw-values.yaml
```

## Option 2: Installation with external DB (external MySQL)

### 1) Initialize schemas on the external DB

This uses the SQL in `mysql-scripts`.

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

### 3) Install MetalLB for LoadBalancer support

MetalLB is required for stable external IPs on Kind:

```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.3/config/manifests/metallb-native.yaml

# Create IP pool (adjust for your network)
kubectl apply -f metal-ippool.yaml

# Wait for external IP assignment
kubectl get svc -n istio-system istio-ingressgateway -w
```

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




## APK (WSO2 API Platform for Kubernetes)

### 1) APIM gateway environment label

This repo expects APIM CP to have an APK gateway environment label `Default_apk` and uses `api.local:9095` as its hostname.

If APIM is already installed, re-run the APIM Helm command above (it reads `apim-cp-values.yaml`).

### 2) Install APK 1.3.0-1

This repo vendors the chart under `apk-helm-1.3.0-1/apk-helm`.

```bash
helm upgrade --install apk apk-helm-1.3.0-1/apk-helm \
  -n apk --create-namespace \
  -f apk-values.local.yaml 
```

### 3) Install APIM → APK Agent (CP→DP)

```bash
helm repo add wso2apkagent https://github.com/wso2/product-apim-tooling/releases/download/1.3.0
helm repo update

helm upgrade --install apim-apk-agent wso2apkagent/apim-apk-agent \
  --version 1.3.0 \
  -n apk \
  -f apim-apk-agent-values.local.yaml
```

### 4) Verify

```bash
helm list -A
kubectl get pods -n apk
kubectl logs -n apk deploy/apim-apk-agent --tail=50
```



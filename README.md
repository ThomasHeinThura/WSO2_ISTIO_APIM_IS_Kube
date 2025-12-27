# WSO2 APIM 4.6.0 (Control Plane + Universal Gateway) on Kind + Istio

This folder provides a repeatable setup for APIM 4.6.0 **Control Plane** + **Universal Gateway** on a local Kind cluster with Istio ingress.

This README supports exactly two installation paths:

1) **Installation with Kubernetes DB** (MySQL runs inside the cluster)
2) **Installation with external DB** (you bring your own MySQL)

## Prerequisites

- Docker
- Kind
- kubectl
- Helm
- istioctl

## Common steps (both DB options)

### 1) Create Kind cluster

```bash
kind create cluster --name wso2-cluster --config WSO2_ISTIO_APIM_IS_Kube/Kubernetes_cluster/kind.yaml
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
./WSO2_ISTIO_APIM_IS_Kube/scripts/generate-local-certificates.sh

# Create the keystore secret
kubectl create secret generic apim-keystore-secret \
  --from-file=wso2carbon.jks=WSO2_ISTIO_APIM_IS_Kube/scripts/wso2carbon.jks \
  --from-file=client-truststore.jks=WSO2_ISTIO_APIM_IS_Kube/scripts/client-truststore.jks \
  -n wso2
```

### 5) Build APIM images (MySQL JDBC included) and load into Kind

```bash
LOAD_TO_KIND=true ./WSO2_ISTIO_APIM_IS_Kube/scripts/build-apim-images.sh
```

## Option 1: Installation with Kubernetes DB (in-cluster MySQL)

### 1) Deploy MySQL to the cluster

```bash
./WSO2_ISTIO_APIM_IS_Kube/scripts/deploy-mysql.sh
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
  -f WSO2_ISTIO_APIM_IS_Kube/apim-cp-values.yaml

helm install apim-gw wso2/wso2am-universal-gw \
  --version 4.6.0-1 \
  -n wso2 \
  -f WSO2_ISTIO_APIM_IS_Kube/apim-gw-values.yaml
```

## Option 2: Installation with external DB (external MySQL)

### 1) Initialize schemas on the external DB

This uses the SQL in `WSO2_ISTIO_APIM_IS_Kube/mysql-scripts`.

```bash
DB_PASSWORD='<mysql-root-password>' \
  ./WSO2_ISTIO_APIM_IS_Kube/scripts/init-external-mysql.sh
```

### 2) Ensure values files point to the external DB

- Update the DB host/port/user/password in:
  - `WSO2_ISTIO_APIM_IS_Kube/apim-cp-values.yaml`
  - `WSO2_ISTIO_APIM_IS_Kube/apim-gw-values.yaml`

Important: if a JDBC URL is rendered into XML, keep it XML-safe (escape `&` as `&amp;`).

### 3) Install APIM Control Plane + Universal Gateway

Same Helm commands as Option 1.

### 3) Install MetalLB for LoadBalancer support

MetalLB is required for stable external IPs on Kind:

```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# Create IP pool (adjust for your network)
kubectl apply -f WSO2_ISTIO_APIM_IS_Kube/metal-ippool.yaml

# Wait for external IP assignment
kubectl get svc -n istio-system istio-ingressgateway -w
```

## Istio external access (gw.local / apim.local)

### 1) Apply Istio Gateway + VirtualServices

```bash
kubectl apply -f WSO2_ISTIO_APIM_IS_Kube/istio-gateway.yaml
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



<pre class="prism-code language-bash"><div class="token-line"><span class="token plain">kubectl apply </span><span class="token parameter variable">-f</span><span class="token plain"> https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml</span></div></pre>

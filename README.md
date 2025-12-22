# WSO2 APIM + IS + APK with Istio (POC)

This project demonstrates a Proof of Concept (POC) integration of WSO2 API Manager (APIM), WSO2 Identity Server (IS), and WSO2 API Platform for Kubernetes (APK) running on a Kubernetes cluster with Istio Service Mesh.

## 🏗 Architecture

The deployment uses a **Kind** cluster with **Istio** for traffic management and mTLS.

| Component | Namespace | Role | Service Name |
|-----------|-----------|------|--------------|
| **WSO2 IS** | `wso2` | Key Manager (Auth) | `wso2-is-service` |
| **APIM CP** | `wso2` | Control Plane | `wso2-apim-cp-service` |
| **APIM GW** | `wso2` | Classic Gateway | `wso2-apim-gw-service` |
| **APK CP** | `wso2-apk` | APK Control Plane | `apk-cp-service` |
| **APK Router**| `wso2-apk` | Envoy Gateway | `apk-router-service` |

**Traffic Flow:**
- **Ingress**: `istio-ingressgateway` handles external traffic for APIM and IS.
- **Internal**: APIM communicates with IS via K8s Service DNS (`wso2-is-service.wso2.svc`).
- **APK**: Uses its own LoadBalancer/NodePort service (Envoy).

## 📂 Directory Structure

- `values-poc-apim.yaml`: Helm overrides for APIM (Pattern 2 + IS Key Manager).
- `values-poc-is.yaml`: Helm overrides for Identity Server.
- `values-poc-apk.yaml`: Helm overrides for APK (Control Plane Enabled).
- `istio-gateway.yaml`: Istio Gateway and VirtualService definitions.
- `scripts/`: Helper scripts for deployment.

## 🚀 Getting Started

### Prerequisites
- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/)
- [Helm](https://helm.sh/)
- [Istio CLI (istioctl)](https://istio.io/latest/docs/setup/getting-started/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)

### 1. Setup Cluster & Istio

```bash
# Create Cluster
kind create cluster --name wso2-poc

# Install Istio
istioctl install --set profile=demo -y

# Create Namespaces & Enable Injection
kubectl create ns wso2
kubectl create ns wso2-apk
kubectl label ns wso2 istio-injection=enabled
kubectl label ns wso2-apk istio-injection=enabled
```

### 2. Deploy MySQL

```bash
# From WSO2_ISTIO_APIM_IS_Kube/scripts
cd WSO2_ISTIO_APIM_IS_Kube/scripts
./deploy-mysql.sh
cd ../..
```

### 3. Deploy WSO2 Identity Server (IS)

```bash
# From workspace root
helm install wso2-is ./kubernetes-is \
  -f WSO2_ISTIO_APIM_IS_Kube/values-poc-is.yaml \
  -n wso2
```

### 4. Deploy WSO2 API Manager (APIM)

```bash
# From workspace root
helm install wso2-apim ./helm-apim/all-in-one \
  -f WSO2_ISTIO_APIM_IS_Kube/values-poc-apim.yaml \
  -n wso2
```

### 5. Deploy WSO2 APK

```bash
# From workspace root
helm install wso2-apk ./apk/helm-charts \
  -f WSO2_ISTIO_APIM_IS_Kube/values-poc-apk.yaml \
  -n wso2-apk
```

### 6. Configure Ingress

```bash
kubectl apply -f WSO2_ISTIO_APIM_IS_Kube/istio-gateway.yaml
```

### 6. Accessing Services

Add the following to your `/etc/hosts`:
```
127.0.0.1 apim.local is.local
```

- **APIM Publisher**: `https://apim.local/publisher`
- **APIM DevPortal**: `https://apim.local/devportal`
- **Identity Server**: `https://is.local/console`

## 🔧 Configuration Details

### IS as Key Manager
APIM is configured to use WSO2 IS as the Key Manager. This is defined in `values-poc-apim.yaml`:
```yaml
apim:
  keyManager:
    type: "WSO2-IS"
    url: "https://wso2-is-service.wso2.svc.cluster.local:9443"
```

### Database
For this POC, we are using a **MySQL 8.0** pod deployed in the cluster.
- **Scripts**: Initialization scripts are mounted from `mysql-scripts/`.
- **Connection**: Both APIM and IS connect to `mysql.wso2.svc.cluster.local`.
- **Databases**:
  - `WSO2AM_DB` (APIM)
  - `WSO2AM_SHARED_DB` (APIM Shared)
  - `WSO2IS_IDENTITY_DB` (IS Identity & Consent)
  - `WSO2IS_SHARED_DB` (IS Shared & User)

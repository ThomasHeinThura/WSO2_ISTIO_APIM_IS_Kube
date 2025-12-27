# APIM 4.6.0 (CP + Universal GW) on Kind + Istio (Helm)

This is the Helm-focused guide for installing APIM 4.6.0 Control Plane + Universal Gateway.

For the end-to-end flow (Kind → istioctl → secrets → DB → Helm → Istio Gateway), use:

- `WSO2_ISTIO_APIM_IS_Kube/README.md`

## Versions

- APIM: 4.6.0 (charts: `4.6.0-1`)
- IS: 7.2 (later)
- APK: 1.3.0 (later)

## Assumptions

- Kind cluster already created with `WSO2_ISTIO_APIM_IS_Kube/Kubernetes_cluster/kind.yaml`.
- Istio installed via `istioctl install` (includes ingress gateway).

DB options supported:

- Kubernetes DB (MySQL in-cluster)
- External DB (your MySQL)

Note: `istio/base` + `istiod` alone does **not** expose any ingress. If you want to reach APIM from your laptop via `apim.local` / `gw.local`, you must also install an Istio ingress gateway (Helm chart `istio/gateway`) and expose it (NodePort/port-mapping) to match your Kind config.

## 1) Add WSO2 Helm repo

```bash
helm repo add wso2 https://helm.wso2.com
helm repo update
```

## 2) Database setup

### Option A) Kubernetes DB (in-cluster MySQL)

Deploy MySQL:

```bash
./WSO2_ISTIO_APIM_IS_Kube/scripts/deploy-mysql.sh
```

### Option B) External DB (your MySQL)

Initialize schemas using the SQL in `WSO2_ISTIO_APIM_IS_Kube/mysql-scripts`:

```bash
DB_PASSWORD='<mysql-root-password>' \
  ./WSO2_ISTIO_APIM_IS_Kube/scripts/init-external-mysql.sh
```

(When you install IS later)

```bash
DB_PASSWORD='1qaz!QAZ' INCLUDE_IS=true \
  ./WSO2_ISTIO_APIM_IS_Kube/scripts/init-external-mysql.sh
```

## 3) Create APIM keystore secret

This uses the JKS files already present in `WSO2_ISTIO_APIM_IS_Kube/Reference/` (`wso2carbon.jks`, `client-truststore.jks`) and creates `apim-keystore-secret` in `wso2`.

If the JKS files are not present, the script falls back to extracting them from `WSO2_ISTIO_APIM_IS_Kube/Reference/wso2am-4.6.0.zip`.

```bash
./WSO2_ISTIO_APIM_IS_Kube/scripts/create-apim-keystore-secret.sh
```

## 4) Build images (MySQL JDBC included) and load into Kind

This builds:

- `bimdevops/wso2-apim-cp-mysql:4.6.0`
- `bimdevops/wso2-apim-gw-mysql:4.6.0`

```bash
./WSO2_ISTIO_APIM_IS_Kube/scripts/build-apim-images.sh
```

By default this script **pushes to Docker Hub**. Run `docker login` first.
If you want to also load images into Kind nodes (offline/no-pull), run:

```bash
LOAD_TO_KIND=true ./WSO2_ISTIO_APIM_IS_Kube/scripts/build-apim-images.sh
```

Notes:

- CP image defaults to base `wso2/wso2am:4.6.0`.
- Universal GW base defaults to `wso2/wso2am-universal-gw:4.6.0`.
  - If you use a different registry/image, override: `GW_BASE_IMAGE=... ./.../build-apim-images.sh`.

## 5) Install APIM (Control Plane / All-in-One) + Universal GW

We install into namespace `wso2` and keep release names stable because GW points to the CP service name.

```bash
kubectl create ns wso2 --dry-run=client -o yaml | kubectl apply -f -

helm install apim wso2/wso2am-all-in-one \
  --version 4.6.0-1 \
  -n wso2 \
  -f WSO2_ISTIO_APIM_IS_Kube/apim-cp-values.yaml

helm install apim-gw wso2/wso2am-universal-gw \
  --version 4.6.0-1 \
  -n wso2 \
  -f WSO2_ISTIO_APIM_IS_Kube/apim-gw-values.yaml

## 6) Istio external access
Apply Istio routing:
```bash
kubectl apply -f WSO2_ISTIO_APIM_IS_Kube/istio-gateway.yaml
```

Hostnames used by this repo:

- `apim.local` (Control Plane)
- `gw.local` (Gateway)

If Kind port-mapping is enabled for 80/443, add to `/etc/hosts`:

```text
127.0.0.1 gw.local apim.local
```

```

## 6) Verify
```bash
kubectl get pods -n wso2
kubectl get svc -n wso2
```

## Values files

- CP: [WSO2_ISTIO_APIM_IS_Kube/apim-cp-values.yaml](WSO2_ISTIO_APIM_IS_Kube/apim-cp-values.yaml)
- GW: [WSO2_ISTIO_APIM_IS_Kube/apim-gw-values.yaml](WSO2_ISTIO_APIM_IS_Kube/apim-gw-values.yaml)

## Next steps (later)

- Install IS 7.2 and then flip `iskm.enabled: true` in the APIM values.
- Add APK and configure multiple gateway environments in APIM (`Regular` + `APK`).

## Git note

This repo includes a `.gitignore` that excludes JKS files and large downloaded archives/product packs by default.

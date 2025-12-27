kind create cluster --config=./WSO2_ISTIO_APIM_IS_Kube/Kubernetes_cluster/kind.yaml



### Install Istio with side-car

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

helm install istio-base istio/base -n istio-system --set defaultRevision=default --create-namespace

helm install istiod istio/istiod -n istio-system --wait

#!/bin/bash
set -e

# Load variables
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
else
    echo ".env file not found!"
    exit 1
fi

echo "--- STARTING FRESH INSTALL ---"

# 1. Cleanup existing RabbitMQ Operators and Namespaces
echo "Step 0: Cleaning up existing installations..."
helm uninstall tanzu-rabbitmq -n "$OPERATOR_NAMESPACE" 2>/dev/null || true
helm uninstall cert-manager -n cert-manager 2>/dev/null || true

# Delete namespaces to wipe all secrets and stuck pods
# We use --wait=false to speed things up, but then wait manually for namespaces to vanish
kubectl delete namespace "$OPERATOR_NAMESPACE" --ignore-not-found=true
kubectl delete namespace cert-manager --ignore-not-found=true

echo "Waiting for namespaces to be fully removed..."
while kubectl get ns cert-manager >/dev/null 2>&1 || kubectl get ns "$OPERATOR_NAMESPACE" >/dev/null 2>&1; do
    sleep 2
done

# 2. Install Cert-Manager
echo "Step 1: Installing cert-manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Using your OCI path and setting installCRDs=true
helm install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version "$CERT_MANAGER_VERSION" \
  --namespace cert-manager \
  --create-namespace

Sleep 30s;

# 3. Tanzu Registry Login
echo "Step 2: Logging into Tanzu Helm Registry..."
echo "$BROADCOM_TOKEN" | helm registry login rabbitmq-helmoci.packages.broadcom.com \
  --username "$BROADCOM_USERNAME" \
  --password-stdin

# 4. Setup Operator Namespace and Secrets
echo "Step 3: Creating namespace: $OPERATOR_NAMESPACE"
kubectl create namespace "$OPERATOR_NAMESPACE"

echo "Step 4: Creating Image Pull Secrets..."
# IMPORTANT: Creating separate secrets for the two distinct Broadcom domains
# Secret for Server/Cluster images
kubectl create secret docker-registry "$REGISTRY_SECRET_NAME" \
  --docker-server="rabbitmq.packages.broadcom.com" \
  --docker-username="$BROADCOM_USERNAME" \
  --docker-password="$BROADCOM_TOKEN" \
  --namespace "$OPERATOR_NAMESPACE"

# Secret for Operator images (Prevents 403 Forbidden)
kubectl create secret docker-registry "$OPERATOR_SECRET_NAME" \
  --docker-server="rabbitmq-operator.packages.broadcom.com" \
  --docker-username="$BROADCOM_USERNAME" \
  --docker-password="$BROADCOM_TOKEN" \
  --namespace "$OPERATOR_NAMESPACE"

# 5. Install Tanzu RabbitMQ Operators with Secrets Mapped
echo "Step 5: Installing Tanzu RabbitMQ Operators..."
# We pass the OPERATOR_SECRET_NAME to the operators so they can pull their own images
helm install tanzu-rabbitmq $OPERATOR_CHART_URL \
  --version $TANZU_RMQ_VERSION \
  --namespace $OPERATOR_NAMESPACE \
  --set clusterOperator.imagePullSecrets[0].name=operators-registry-creds \
  --set msgTopologyOperator.imagePullSecrets[0].name=operators-registry-creds

echo "--------------------------------------------------"
echo "Installation Complete!"
echo "Cert-manager and Tanzu RabbitMQ Operators are fresh and ready."

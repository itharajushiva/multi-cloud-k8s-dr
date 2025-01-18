#!/usr/bin/env bash
# ==============================================================================
# Script: install-velero.sh
# Purpose: Installs Velero via Helm on either AWS EKS or Azure AKS using
#          workload identities (IRSA / Azure Workload Identity).
# Usage: ./install-velero.sh <aws|azure>
# ==============================================================================

set -euo pipefail

TARGET_CLOUD="${1:-}"

if [[ -z "$TARGET_CLOUD" || ! "$TARGET_CLOUD" =~ ^(aws|azure)$ ]]; then
  echo "[-] Error: Target cluster parameter required."
  echo "Usage: $0 <aws|azure>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "[+] Initializing Velero Helm installation on: ${TARGET_CLOUD^^}"

# Ensure Helm repository is added
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts >/dev/null 2>&1
helm repo update vmware-tanzu

kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

if [[ "$TARGET_CLOUD" == "aws" ]]; then
  echo "[+] Deploying Velero on AWS EKS..."
  helm upgrade --install velero vmware-tanzu/velero \
    --namespace velero \
    -f "${PROJECT_ROOT}/velero/aws/values.yaml" \
    --wait
elif [[ "$TARGET_CLOUD" == "azure" ]]; then
  echo "[+] Applying Azure Storage Class Mapping ConfigMap..."
  kubectl apply -f "${PROJECT_ROOT}/velero/azure/storage-class-mapping-configmap.yaml"

  echo "[+] Deploying Velero on Azure AKS..."
  helm upgrade --install velero vmware-tanzu/velero \
    --namespace velero \
    -f "${PROJECT_ROOT}/velero/azure/values.yaml" \
    --wait
fi

echo "[+] Verifying Velero server deployment..."
kubectl rollout status deployment/velero -n velero --timeout=180s
echo "[+] Velero installed and running successfully!"

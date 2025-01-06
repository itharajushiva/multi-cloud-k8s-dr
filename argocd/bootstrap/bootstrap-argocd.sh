#!/usr/bin/env bash
# ==============================================================================
# Script: bootstrap-argocd.sh
# Purpose: Installs Argo CD on target Kubernetes cluster, sets up root admin password,
#          and creates core application CRDs.
# Usage: ./bootstrap-argocd.sh <aws|azure>
# ==============================================================================

set -euo pipefail

TARGET_CLOUD="${1:-}"

if [[ -z "$TARGET_CLOUD" || ! "$TARGET_CLOUD" =~ ^(aws|azure)$ ]]; then
  echo "[-] Error: Target cloud parameter missing or invalid."
  echo "Usage: $0 <aws|azure>"
  exit 1
fi

echo "[+] Bootstrapping Argo CD on target cluster: ${TARGET_CLOUD^^}"

# Create argocd namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install official Argo CD release
echo "[+] Applying Argo CD official installation manifests..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.1/manifests/install.yaml

# Wait for Argo CD server deployment readiness
echo "[+] Waiting for Argo CD server to be ready (timeout: 300s)..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "[+] Argo CD successfully deployed!"
echo "[+] Initial admin secret extraction:"
echo "--------------------------------------------------------"
if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
  ADMIN_PASS=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)
  echo "Username: admin"
  echo "Password: ${ADMIN_PASS}"
else
  echo "[i] argocd-initial-admin-secret not found (already changed or initialized)."
fi
echo "--------------------------------------------------------"
echo "[+] To access web UI locally: kubectl port-forward svc/argocd-server -n argocd 8080:443"

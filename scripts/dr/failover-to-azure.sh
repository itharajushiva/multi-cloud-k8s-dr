#!/usr/bin/env bash
# ==============================================================================
# Script: failover-to-azure.sh
# Purpose: Orchestrates emergency failover from AWS EKS Primary to Azure AKS Standby.
# Steps:
#   1. Verifies latest available Velero backup
#   2. Restores persistent storage & stateful workloads to AKS
#   3. Triggers Argo CD synchronization on Azure AKS for declarative workloads
#   4. Directs ingress traffic to Azure public IP / CNAME
# Usage: ./failover-to-azure.sh [backup_name]
# ==============================================================================

set -euo pipefail

BACKUP_NAME="${1:-}"

echo "============================================================"
echo " [ALERT] INITIATING EMERGENCY FAILOVER TO AZURE AKS"
echo " Time: $(date -u +"%Y-%m-%d %H:%M:%SZ")"
echo "============================================================"

# Ensure kubeconfig context is set to Azure Standby
CURRENT_CONTEXT=$(kubectl config current-context)
echo "[+] Current Kubernetes Context: ${CURRENT_CONTEXT}"
read -p "Are you sure you want to failover to this context? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Failover aborted by operator."
  exit 0
fi

# Step 1: Identify latest backup if not provided
if [[ -z "$BACKUP_NAME" ]]; then
  echo "[+] Locating most recent completed backup..."
  BACKUP_NAME=$(velero backup get -o json | grep -B 2 '"phase": "Completed"' | grep '"name":' | head -n 1 | cut -d'"' -f4)
  echo "[+] Selected latest backup: ${BACKUP_NAME}"
fi

# Step 2: Restore PVs and Stateful Data via Velero
echo "[+] Step 1/3: Restoring Persistent Volumes and state from backup..."
FAILOVER_RESTORE="failover-restore-$(date +%Y%m%d%H%M%S)"
velero restore create "${FAILOVER_RESTORE}" \
  --from-backup "${BACKUP_NAME}" \
  --include-namespaces guestbook \
  --restore-volumes=true \
  --wait

echo "[+] Restore completed. Verifying pods status..."
kubectl get pods -n guestbook

# Step 3: Sync Argo CD to ensure GitOps state matches desired repository state
echo "[+] Step 2/3: Triggering Argo CD sync on Azure AKS..."
if command -v argocd &> /dev/null; then
  argocd app sync guestbook-azure-standby --prune || echo "[i] Argo CD CLI sync warning - checking CRD directly"
else
  echo "[+] Triggering manual refresh via kubectl patch..."
  kubectl patch application guestbook-azure-standby -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' || true
fi

# Step 4: Output DNS failover endpoints
echo "[+] Step 3/3: Retrieving Azure ingress public IP / hostname..."
echo "Waiting for External IP..."
for i in {1..30}; do
  INGRESS_IP=$(kubectl get svc frontend -n guestbook -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || true)
  if [[ -n "$INGRESS_IP" ]]; then
    break
  fi
  sleep 5
done

echo "============================================================"
echo " [SUCCESS] FAILOVER COMPLETED!"
echo " Azure AKS Ingress IP: ${INGRESS_IP:-Pending (run: kubectl get svc frontend -n guestbook)}"
echo " Update your Route 53 / Cloudflare DNS records to point to ${INGRESS_IP}"
echo " Failover documentation reference: docs/runbooks/failover-runbook.md"
echo "============================================================"

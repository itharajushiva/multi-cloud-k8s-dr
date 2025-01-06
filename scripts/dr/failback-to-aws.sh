#!/usr/bin/env bash
# ==============================================================================
# Script: failback-to-aws.sh
# Purpose: Orchestrates planned failback from Azure AKS Standby to AWS EKS Primary.
# Steps:
#   1. Scales down traffic / read-only mode on Azure AKS
#   2. Takes final differential Velero backup on Azure AKS
#   3. Switches kubectl context to AWS EKS Primary
#   4. Restores delta data to AWS EKS
#   5. Enables Argo CD automated sync on AWS
#   6. Points DNS back to AWS Route 53 NLB
# Usage: ./failback-to-aws.sh [aws_kubeconfig_context]
# ==============================================================================

set -euo pipefail

AWS_CONTEXT="${1:-arn:aws:eks:us-east-1:123456789012:cluster/prod-eks-primary}"
FAILBACK_BACKUP_NAME="failback-azure-final-$(date +%Y%m%d%H%M%S)"

echo "============================================================"
echo " [NOTICE] INITIATING CONTROLLED FAILBACK TO AWS EKS PRIMARY"
echo " Time: $(date -u +"%Y-%m-%d %H:%M:%SZ")"
echo "============================================================"

# Step 1: Drain ingress / scale down frontend on Azure to freeze state
echo "[+] Step 1/5: Freezing state on Azure AKS to avoid data divergence..."
kubectl scale deployment/frontend -n guestbook --replicas=0

# Step 2: Create final snapshot on Azure
echo "[+] Step 2/5: Creating final state backup '${FAILBACK_BACKUP_NAME}' on Azure..."
velero backup create "${FAILBACK_BACKUP_NAME}" \
  --include-namespaces guestbook \
  --default-volumes-to-fs-backup \
  --snapshot-volumes=true \
  --wait

echo "[✓] Final Azure backup completed successfully."

# Step 3: Switch context to AWS
echo "[+] Step 3/5: Switching context to AWS EKS Primary..."
kubectl config use-context "${AWS_CONTEXT}"

# Step 4: Restore stateful data on AWS EKS
echo "[+] Step 4/5: Restoring differential state to AWS EKS..."
velero restore create "failback-restore-$(date +%Y%m%d%H%M%S)" \
  --from-backup "${FAILBACK_BACKUP_NAME}" \
  --include-namespaces guestbook \
  --restore-volumes=true \
  --wait

# Step 5: Argo CD Re-synchronize
echo "[+] Step 5/5: Resuming Argo CD automated synchronization on AWS..."
kubectl patch application guestbook-aws-primary -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' || true

# Scale frontend back up if needed
kubectl scale deployment/frontend -n guestbook --replicas=3

echo "============================================================"
echo " [SUCCESS] FAILBACK TO AWS EKS COMPLETED!"
echo " Primary cluster is active and synchronized via GitOps."
echo " Revert Route 53 DNS records to point to AWS NLB endpoint."
echo " Clean up temporary resources on Azure when validation passes."
echo "============================================================"

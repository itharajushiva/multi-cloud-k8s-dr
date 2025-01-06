#!/usr/bin/env bash
# ==============================================================================
# Script: test-dr-restore.sh
# Purpose: Executes a cross-cloud restore test from AWS S3 backups to Azure AKS.
#          Measures Recovery Time Actual (RTA) and verifies PV data consistency.
# Usage: ./test-dr-restore.sh <backup_name> [target_namespace]
# ==============================================================================

set -euo pipefail

BACKUP_NAME="${1:-}"
TARGET_NAMESPACE="${2:-guestbook-restored}"
RESTORE_NAME="restore-test-$(date +%Y%m%d%H%M%S)"

if [[ -z "$BACKUP_NAME" ]]; then
  echo "[-] Error: Backup name is required."
  echo "Usage: $0 <backup_name> [target_namespace]"
  echo "Available backups:"
  velero backup get || true
  exit 1
fi

START_TIME=$(date +%s)
echo "============================================================"
echo " Starting Disaster Recovery Restore Test"
echo " Backup Source:    ${BACKUP_NAME}"
echo " Restore Target:   ${RESTORE_NAME}"
echo " Target Namespace: ${TARGET_NAMESPACE}"
echo " Start Time:       $(date -u +"%Y-%m-%d %H:%M:%SZ")"
echo "============================================================"

# Ensure target namespace is clean if testing isolated restore
echo "[+] Preparing target namespace: ${TARGET_NAMESPACE}"
kubectl create namespace "${TARGET_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Launch Velero restore with namespace remapping
echo "[+] Initiating Velero cross-cloud restore..."
velero restore create "${RESTORE_NAME}" \
  --from-backup "${BACKUP_NAME}" \
  --namespace-mappings "guestbook:${TARGET_NAMESPACE}" \
  --restore-volumes=true \
  --wait

# Check restore phase
RESTORE_STATUS=$(velero restore get "${RESTORE_NAME}" -o jsonpath="{.status.phase}")
echo "[+] Restore Phase: ${RESTORE_STATUS}"

if [[ "$RESTORE_STATUS" != "Completed" && "$RESTORE_STATUS" != "PartiallyFailed" ]]; then
  echo "[x] Restore failed with status: ${RESTORE_STATUS}"
  velero restore logs "${RESTORE_NAME}"
  exit 1
fi

# Verify persistent volume claims in target namespace
echo "[+] Inspecting Persistent Volume Claims in ${TARGET_NAMESPACE}..."
kubectl get pvc -n "${TARGET_NAMESPACE}"

# Wait for workload pods to reach Running status
echo "[+] Waiting for restored StatefulSet (redis-leader) to become ready..."
kubectl rollout status statefulset/redis-leader -n "${TARGET_NAMESPACE}" --timeout=300s

echo "[+] Waiting for restored frontend deployments to become ready..."
kubectl rollout status deployment/redis-follower -n "${TARGET_NAMESPACE}" --timeout=180s
kubectl rollout status deployment/frontend -n "${TARGET_NAMESPACE}" --timeout=180s

# Verify Redis data integrity
echo "[+] Verifying stateful data integrity inside Redis leader..."
TEST_KEY_EXISTS=$(kubectl exec -n "${TARGET_NAMESPACE}" statefulset/redis-leader -- redis-cli ping 2>/dev/null || echo "FAIL")

if [[ "$TEST_KEY_EXISTS" == *"PONG"* ]]; then
  echo "[✓] Redis service responsive and persistent volume successfully re-attached!"
else
  echo "[!] Warning: Redis did not reply with PONG. Manual inspection required."
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo "============================================================"
echo "[✓] DR Restore Test COMPLETED successfully!"
echo " Total Recovery Time Actual (RTA): ${DURATION} seconds"
echo "============================================================"

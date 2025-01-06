#!/usr/bin/env bash
# ==============================================================================
# Script: backup-workloads.sh
# Purpose: Triggers an ad-hoc or scheduled Velero backup of workloads and PVs.
# Usage: ./backup-workloads.sh [backup_name] [namespace]
# ==============================================================================

set -euo pipefail

BACKUP_NAME="${1:-dr-workloads-$(date +%Y%m%d%H%M%S)}"
NAMESPACE="${2:-guestbook}"

echo "============================================================"
echo " Starting Velero Backup: ${BACKUP_NAME}"
echo " Target Namespace:       ${NAMESPACE}"
echo " Timestamp:              $(date -u +"%Y-%m-%d %H:%M:%SZ")"
echo "============================================================"

# Ensure Velero CLI is available
if ! command -v velero &> /dev/null; then
  echo "[-] Error: 'velero' CLI tool is not installed or not in PATH."
  exit 1
fi

echo "[+] Creating backup with defaultVolumesToFsBackup enabled..."
velero backup create "${BACKUP_NAME}" \
  --include-namespaces "${NAMESPACE}" \
  --default-volumes-to-fs-backup \
  --snapshot-volumes=true \
  --wait

echo "[+] Inspecting backup status..."
velero backup describe "${BACKUP_NAME}" --details

STATUS=$(velero backup get "${BACKUP_NAME}" -o json | grep -o '"phase": "[^"]*' | cut -d'"' -f4)

if [[ "$STATUS" == "Completed" ]]; then
  echo "[✓] Backup '${BACKUP_NAME}' completed successfully!"
else
  echo "[x] Backup ended with non-completion phase: ${STATUS}"
  echo "Check logs with: velero backup logs ${BACKUP_NAME}"
  exit 1
fi

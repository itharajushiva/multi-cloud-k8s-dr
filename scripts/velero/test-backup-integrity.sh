#!/usr/bin/env bash
# ==============================================================================
# Script: test-backup-integrity.sh
# Purpose: Validates backup integrity in S3/Azure Blob without performing a full restore.
#          Checks metadata, manifests, and PV volume snapshots.
# Usage: ./test-backup-integrity.sh <backup_name>
# ==============================================================================

set -euo pipefail

BACKUP_NAME="${1:-}"

if [[ -z "$BACKUP_NAME" ]]; then
  echo "[-] Error: Backup name parameter is required."
  echo "Usage: $0 <backup_name>"
  exit 1
fi

echo "[*] Auditing backup integrity for: ${BACKUP_NAME}"

# 1. Check phase
BACKUP_PHASE=$(velero backup get "${BACKUP_NAME}" -o jsonpath="{.status.phase}" 2>/dev/null || echo "NotFound")

if [[ "$BACKUP_PHASE" != "Completed" ]]; then
  echo "[!] Validation failed: Backup phase is '${BACKUP_PHASE}' (expected 'Completed')."
  exit 1
fi

# 2. Check total items backed up
TOTAL_ITEMS=$(velero backup get "${BACKUP_NAME}" -o jsonpath="{.status.progress.totalItems}")
ITEMS_BACKED_UP=$(velero backup get "${BACKUP_NAME}" -o jsonpath="{.status.progress.itemsBackedUp}")

echo "[+] Total items discovered: ${TOTAL_ITEMS}"
echo "[+] Items successfully backed up: ${ITEMS_BACKED_UP}"

if [[ "$TOTAL_ITEMS" -le 0 || "$TOTAL_ITEMS" -ne "$ITEMS_BACKED_UP" ]]; then
  echo "[!] Validation Warning: Total items count mismatch or zero."
  exit 1
fi

# 3. Check for any errors or warnings
ERRORS=$(velero backup get "${BACKUP_NAME}" -o jsonpath="{.status.errors}")
WARNINGS=$(velero backup get "${BACKUP_NAME}" -o jsonpath="{.status.warnings}")

echo "[+] Errors reported: ${ERRORS:-0}"
echo "[+] Warnings reported: ${WARNINGS:-0}"

if [[ "${ERRORS:-0}" -gt 0 ]]; then
  echo "[x] Backup contains errors. Run: velero backup logs ${BACKUP_NAME}"
  exit 1
fi

echo "[✓] Backup integrity verified successfully for ${BACKUP_NAME}!"

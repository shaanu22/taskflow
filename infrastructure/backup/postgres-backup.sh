#!/bin/bash
# PostgreSQL backup script for TaskFlow
# Usage: ./postgres-backup.sh <namespace> <backup-dir>

set -euo pipefail

NAMESPACE=${1:-taskflow-prod}
BACKUP_DIR=${2:-/tmp/taskflow-backups}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/taskflow_${NAMESPACE}_${TIMESTAMP}.sql.gz"

echo "Starting backup for namespace: $NAMESPACE"
echo "Backup file: $BACKUP_FILE"

mkdir -p "$BACKUP_DIR"

# Get postgres pod name
POSTGRES_POD=$(kubectl get pod -n "$NAMESPACE" \
  -l component=postgres \
  -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POSTGRES_POD" ]; then
  echo "ERROR: No postgres pod found in namespace $NAMESPACE"
  exit 1
fi

echo "Found postgres pod: $POSTGRES_POD"

# Run pg_dump inside the pod and stream to local file
kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- \
  pg_dump -U taskflow taskflow | gzip > "$BACKUP_FILE"

BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
echo "Backup complete: $BACKUP_FILE ($BACKUP_SIZE)"

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/taskflow_${NAMESPACE}_*.sql.gz 2>/dev/null | \
  tail -n +8 | xargs -r rm -f

echo "Cleanup complete. Current backups:"
ls -lh "$BACKUP_DIR"/taskflow_${NAMESPACE}_*.sql.gz 2>/dev/null || \
  echo "No previous backups found"

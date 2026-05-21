#!/bin/bash
# PostgreSQL restore script for TaskFlow
# Usage: ./postgres-restore.sh <namespace> <backup-file>

set -euo pipefail

NAMESPACE=${1:-taskflow-prod}
BACKUP_FILE=$2

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <namespace> <backup-file>"
  echo "Available backups:"
  ls -lh /tmp/taskflow-backups/*.sql.gz 2>/dev/null || echo "None found"
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "ERROR: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "WARNING: This will overwrite the database in namespace: $NAMESPACE"
echo "Backup file: $BACKUP_FILE"
read -p "Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted"
  exit 0
fi

POSTGRES_POD=$(kubectl get pod -n "$NAMESPACE" \
  -l component=postgres \
  -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POSTGRES_POD" ]; then
  echo "ERROR: No postgres pod found in namespace $NAMESPACE"
  exit 1
fi

echo "Restoring to pod: $POSTGRES_POD"

# Drop and recreate the database
kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- \
  psql -U taskflow -c "DROP DATABASE IF EXISTS taskflow;"
kubectl exec -n "$NAMESPACE" "$POSTGRES_POD" -- \
  psql -U taskflow -c "CREATE DATABASE taskflow;"

# Stream backup file into the pod and restore
gunzip -c "$BACKUP_FILE" | kubectl exec -i -n "$NAMESPACE" "$POSTGRES_POD" -- \
  psql -U taskflow taskflow

echo "Restore complete"

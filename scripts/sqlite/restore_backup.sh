#!/bin/sh
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backups}"
DB_PATH="${DB_PATH:-/mlflow/mlflow.db}"

if [ "$#" -gt 0 ] && [ -n "${1:-}" ]; then
  BACKUP_FILE="$1"
  case "$BACKUP_FILE" in
    /*) ;;
    *) BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE" ;;
  esac

  if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE" >&2
    exit 1
  fi
else
  BACKUP_FILE="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.db' | sort | tail -n 1)"

  if [ -z "$BACKUP_FILE" ]; then
    echo "No .db backup found in $BACKUP_DIR" >&2
    exit 1
  fi
fi

echo "Restoring backup: $BACKUP_FILE"
cp "$BACKUP_FILE" "$DB_PATH"

echo "Restore completed."

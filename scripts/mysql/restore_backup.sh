#!/bin/sh
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backups}"
DB_HOST="${DB_HOST:-backend}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:?DB_USER is not set}"
DB_NAME="${DB_NAME:?DB_NAME is not set}"
# MYSQL_PWD must be set in the environment for password-less authentication

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
  BACKUP_FILE="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.sql.gz' | sort | tail -n 1)"

  if [ -z "$BACKUP_FILE" ]; then
    echo "No .sql.gz backup found in $BACKUP_DIR" >&2
    exit 1
  fi
fi

echo "Restoring backup: $BACKUP_FILE"
gunzip -c "$BACKUP_FILE" | mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME"

echo "Restore completed."

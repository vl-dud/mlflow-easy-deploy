#!/bin/sh
set -eu

BACKUP_DIR="${BACKUP_DIR:-/backups}"
DB_HOST="${DB_HOST:-backend}"
DB_PORT="${DB_PORT:-1433}"
DB_NAME="${DB_NAME:?DB_NAME is not set}"
DB_SA_PASSWORD="${DB_SA_PASSWORD:?DB_SA_PASSWORD is not set}"

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
  BACKUP_FILE="$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.bak' | sort | tail -n 1)"

  if [ -z "$BACKUP_FILE" ]; then
    echo "No .bak backup found in $BACKUP_DIR" >&2
    exit 1
  fi
fi

echo "Restoring backup: $BACKUP_FILE"
/opt/mssql-tools18/bin/sqlcmd \
    -S "${DB_HOST},${DB_PORT}" -U sa -P "${DB_SA_PASSWORD}" -C \
    -Q "RESTORE DATABASE [${DB_NAME}] FROM DISK = N'${BACKUP_FILE}' WITH REPLACE, RECOVERY"

echo "Restore completed."

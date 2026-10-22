#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <backup-file.sql.gz>" >&2
  exit 2
fi

BACKUP_FILE="$1"
if [[ "$BACKUP_FILE" != /* ]]; then
  BACKUP_FILE="$PWD/$BACKUP_FILE"
fi
if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi
if ! gzip -t -- "$BACKUP_FILE"; then
  echo "Backup is not a valid gzip file; refusing to restore." >&2
  exit 1
fi
if [[ ! -r /dev/tty ]]; then
  echo "Restore requires an interactive terminal for confirmation." >&2
  exit 2
fi

echo "This replaces dumped objects in the configured database; it does not drop the database."
read -r -p "Type 'yes' to continue: " CONFIRM < /dev/tty
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Operation cancelled."
  exit 0
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd -- "$PROJECT_DIR"

echo "Restoring from: $BACKUP_FILE"
gzip -dc -- "$BACKUP_FILE" | docker compose exec -T db sh -c \
  'exec psql -v ON_ERROR_STOP=1 --single-transaction -U "$POSTGRES_USER" "$POSTGRES_DB"'

echo "Restore completed successfully."

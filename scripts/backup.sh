#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$PROJECT_DIR/backups"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

if [[ ! "$RETENTION_DAYS" =~ ^[0-9]+$ ]]; then
  echo "RETENTION_DAYS must be a non-negative integer." >&2
  exit 2
fi

mkdir -p -- "$BACKUP_DIR"
umask 077
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
BACKUP_FILE="$BACKUP_DIR/backup_${TIMESTAMP}_$$.sql.gz"
TEMP_FILE="$(mktemp "$BACKUP_DIR/.backup_${TIMESTAMP}_XXXXXX.tmp")"
trap 'rm -f -- "$TEMP_FILE"' EXIT

echo "Creating PostgreSQL backup..."
(
  cd -- "$PROJECT_DIR"
  docker compose exec -T db sh -c 'exec pg_dump --clean --if-exists -U "$POSTGRES_USER" "$POSTGRES_DB"'
) | gzip -c > "$TEMP_FILE"

gzip -t -- "$TEMP_FILE"
if [[ ! -s "$TEMP_FILE" ]]; then
  echo "Backup output is empty; refusing to publish it." >&2
  exit 1
fi

mv -- "$TEMP_FILE" "$BACKUP_FILE"
echo "Backup completed: $BACKUP_FILE"

find "$BACKUP_DIR" -type f -name 'backup_*.sql.gz' -mtime "+$RETENTION_DAYS" -delete
echo "Removed backups older than $RETENTION_DAYS days."

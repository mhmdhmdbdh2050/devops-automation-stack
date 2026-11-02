#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  printf 'Usage: %s --replace <backup-file.dump>\n' "$0" >&2
  printf 'This operation replaces objects contained in the backup in the configured database.\n' >&2
}

if [[ $# -ne 2 || $1 != --replace ]]; then
  usage
  exit 2
fi

backup_file=$2
if [[ ! -f "$backup_file" ]]; then
  printf 'Backup file not found: %s\n' "$backup_file" >&2
  exit 1
fi

if [[ "$backup_file" != *.dump ]]; then
  printf 'Expected a custom-format PostgreSQL .dump file.\n' >&2
  exit 1
fi

printf 'Checking backup archive: %s\n' "$backup_file"
docker compose exec -T db pg_restore --list - < "$backup_file" > /dev/null

printf 'This will drop and recreate objects present in the backup in the configured database.\n'
read -r -p 'Type RESTORE to continue: ' confirmation
if [[ "$confirmation" != RESTORE ]]; then
  printf 'Restore cancelled.\n'
  exit 0
fi

printf 'Restoring backup to the configured PostgreSQL database...\n'
docker compose exec -T db sh -c \
  'pg_restore --clean --if-exists --no-owner --exit-on-error -U "$POSTGRES_USER" -d "$POSTGRES_DB" -' \
  < "$backup_file"

printf 'Restore completed successfully.\n'

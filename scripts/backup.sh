#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

backup_dir=${BACKUP_DIR:-./backups}
timestamp=$(date +'%Y%m%d_%H%M%S')
backup_file="${backup_dir}/backup_${timestamp}_$$.dump"

mkdir -p -- "$backup_dir"
tmp_file=$(mktemp "${backup_file}.tmp.XXXXXX")
trap 'rm -f -- "$tmp_file"' EXIT

printf 'Starting PostgreSQL backup: %s\n' "$timestamp"
docker compose exec -T db sh -c 'pg_dump --format=custom --no-owner -U "$POSTGRES_USER" "$POSTGRES_DB"' > "$tmp_file"
docker compose exec -T db pg_restore --list - < "$tmp_file" > /dev/null
mv -- "$tmp_file" "$backup_file"
trap - EXIT

printf 'Backup verified and saved to: %s\n' "$backup_file"

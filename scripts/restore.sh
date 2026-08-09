#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: ./restore.sh <path_to_backup_file.sql.gz>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "File not found: $BACKUP_FILE"
    exit 1
fi

echo "WARNING: This will overwrite all current data!"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operation cancelled"
    exit 0
fi

echo "Restoring backup from: $BACKUP_FILE"

gunzip -c "$BACKUP_FILE" | docker exec -i tasks_db psql -U postgres tasksdb

echo "Restore completed successfully"

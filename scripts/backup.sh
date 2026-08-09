#!/bin/bash
set -e

# Variables
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups"
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "Starting backup process: $TIMESTAMP"

docker exec tasks_db pg_dump -U postgres tasksdb | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup completed successfully: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi

# Delete backups older than 7 days
find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +7 -delete

echo "Old backups (older than 7 days) have been removed"

#!/bin/bash
set -e

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="/home/azureuser/gcs-backups/mongodb"
TMP_FILE="/tmp/mongodb-dump.gz"

mkdir -p "$BACKUP_DIR"

echo "[+] Cleaning old MongoDB backups older than 7 days..."
find "$BACKUP_DIR" -type f -name "mongodb-*.tar.gz" -mtime +7 -exec rm -f {} \;

# Find MongoDB primary
MONGO_PRIMARY=$(docker ps --format '{{.Names}}' | grep '^mongo' | while read container; do
  if docker exec "$container" mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep -q true; then
    echo "$container"
    break
  fi
done)

if [[ -z "$MONGO_PRIMARY" ]]; then
  echo "[!] No MongoDB primary found"
  exit 1
fi

echo "[+] Starting MongoDB backup..."
docker exec "$MONGO_PRIMARY" mongodump --gzip --archive=/data/dump.gz --db=mydb --collection=users
docker cp "$MONGO_PRIMARY":/data/dump.gz "$TMP_FILE"

tar -czf "$BACKUP_DIR/mongodb-$TIMESTAMP.tar.gz" -C /tmp mongodb-dump.gz
rm -f "$TMP_FILE"

echo "[✓] MongoDB backup saved to $BACKUP_DIR/mongodb-$TIMESTAMP.tar.gz"


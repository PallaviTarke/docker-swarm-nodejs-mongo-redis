#!/bin/bash
set -e

MONGO_BACKUP=$(find /home/azureuser/gcs-backups/mongodb -type f -name "mongodb-*.tar.gz" | sort | tail -n1)
REDIS_BACKUP=$(find /home/azureuser/gcs-backups/redis -type f -name "redis-*.tar.gz" | sort | tail -n1)
TMP_RESTORE="/tmp/restore"

echo "[+] Selected MongoDB backup: $MONGO_BACKUP"
echo "[+] Selected Redis backup: $REDIS_BACKUP"

# === Restore MongoDB ===
echo "[+] Restoring MongoDB..."
MONGO_PRIMARY=$(docker ps --format '{{.Names}}' | grep '^mongo' | while read container; do
  if docker exec "$container" mongosh --quiet --eval 'db.hello().isWritablePrimary' | grep -q true; then
    echo "$container"
    break
  fi
done)

mkdir -p "$TMP_RESTORE/mongo"
tar -xzf "$MONGO_BACKUP" -C "$TMP_RESTORE/mongo"
docker cp "$TMP_RESTORE/mongo/mongodb-dump.gz" "$MONGO_PRIMARY":/data/restore.gz
docker exec "$MONGO_PRIMARY" mongorestore --gzip --archive=/data/restore.gz --drop
echo "[✓] MongoDB restore done."

# === Restore Redis ===
echo "[+] Restoring Redis..."
REDIS_MASTER=$(docker ps --format '{{.Names}}' | grep 'redis-master')
REDIS_DATA=$(docker inspect "$REDIS_MASTER" -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}')

docker stop "$REDIS_MASTER"
rm -rf "$TMP_RESTORE/redis"
mkdir -p "$TMP_RESTORE/redis"
tar -xzf "$REDIS_BACKUP" -C "$TMP_RESTORE/redis"

sudo rm -rf "$REDIS_DATA"/*
sudo cp -r "$TMP_RESTORE/redis"/* "$REDIS_DATA"

docker start "$REDIS_MASTER"
echo "[✓] Redis restore done."

rm -rf "$TMP_RESTORE"
echo "[✓] Full restore completed."

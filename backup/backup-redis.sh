#!/bin/bash
set -e

# === CONFIG ===
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="/home/azureuser/gcs-backups/redis"
TMP_DIR="/tmp/redis-backup"

mkdir -p "$BACKUP_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

echo "[+] Cleaning old Redis backups older than 7 days..."
find "$BACKUP_DIR" -type f -name "redis-*.tar.gz" -mtime +7 -exec rm -f {} \;

echo "[+] Detecting Redis master via Sentinel..."
REDIS_MASTER_IP=$(docker exec redis-sentinel1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster | sed -n 1p)

if [[ -z "$REDIS_MASTER_IP" ]]; then
  echo "[!] Could not detect Redis master IP"
  exit 1
fi

REDIS_MASTER=$(docker ps -q | while read cid; do
  IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$cid")
  NAME=$(docker inspect -f '{{.Name}}' "$cid" | sed 's/^\///')
  if [[ "$IP" == "$REDIS_MASTER_IP" ]]; then
    echo "$NAME"
    break
  fi
done)

if [[ -z "$REDIS_MASTER" ]]; then
  echo "[!] Could not map Redis master IP to a container"
  exit 1
fi
echo "[✓] Redis master: $REDIS_MASTER"

echo "[+] Forcing Redis to persist data to disk (SAVE)..."
docker exec "$REDIS_MASTER" redis-cli SAVE

REDIS_DATA=$(docker inspect "$REDIS_MASTER" -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}')

if [[ -z "$REDIS_DATA" ]]; then
  echo "[!] Could not determine Redis data mount"
  exit 1
fi

echo "[i] Detected Redis data dir: $REDIS_DATA"

if ! sudo test -d "$REDIS_DATA"; then
  echo "[!] Redis data path not accessible: $REDIS_DATA"
  exit 1
fi

echo "[+] Starting Redis backup..."
sudo cp -r "$REDIS_DATA"/* "$TMP_DIR"
tar -czf "$BACKUP_DIR/redis-$TIMESTAMP.tar.gz" -C "$TMP_DIR" .

echo "[✓] Redis backup saved to $BACKUP_DIR/redis-$TIMESTAMP.tar.gz"


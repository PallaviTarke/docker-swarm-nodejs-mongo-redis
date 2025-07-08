#!/bin/sh

echo "⏳ Waiting for redis-master DNS to resolve..."
until getent hosts redis-master > /dev/null; do
  sleep 2
done
echo "✅ DNS for redis-master resolved!"

echo "⏳ Waiting for redis-master to be ready..."
until redis-cli -h redis-master ping | grep -q PONG; do
  sleep 2
done
echo "✅ redis-master is up!"

REDIS_MASTER_IP=$(getent hosts redis-master | awk '{ print $1 }')
echo "🧠 Resolved redis-master IP: $REDIS_MASTER_IP"

SENTINEL_CONF="/data/sentinel.conf"
touch "$SENTINEL_CONF"

exec redis-server "$SENTINEL_CONF" \
  --sentinel \
  --port 26379 \
  --sentinel monitor mymaster "$REDIS_MASTER_IP" 6379 2 \
  --sentinel down-after-milliseconds mymaster 5000 \
  --sentinel failover-timeout mymaster 10000 \
  --sentinel parallel-syncs mymaster 1


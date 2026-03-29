#!/bin/bash
set -e

STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
DOCKER_DATA="${STORAGE_ROOT}/docker"
LOG_DIR="${STORAGE_ROOT}/logs"

echo "[entrypoint] Storage root : $STORAGE_ROOT"
echo "[entrypoint] Docker data  : $DOCKER_DATA"

mkdir -p "$DOCKER_DATA" "$LOG_DIR" "$STORAGE_ROOT/data"

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DAEMON'
{
  "data-root": "/storage/docker",
  "storage-driver": "vfs",
  "iptables": false,
  "ip6tables": false,
  "ip-masq": false,
  "bridge": "none",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
DAEMON

echo "[entrypoint] Starting Docker daemon..."
dockerd \
  --host=unix:///var/run/docker.sock \
  --config-file=/etc/docker/daemon.json \
  --log-level=warn \
  >> "$LOG_DIR/dockerd.log" 2>&1 &

echo "[entrypoint] Waiting for Docker daemon..."
for i in $(seq 1 90); do
  if docker info > /dev/null 2>&1; then
    echo "[entrypoint] Docker ready (${i}s)"
    break
  fi
  if [ "$i" -eq 90 ]; then
    echo "[entrypoint] ERROR: Docker daemon did not start."
    tail -40 "$LOG_DIR/dockerd.log" || true
    exit 1
  fi
  sleep 1
done

# Do NOT build Dockerfile.vps here on Railway.
# That build is what triggers the mount permission error.

echo "[entrypoint] Waiting for network..."
for i in $(seq 1 30); do
  if python - <<'PY'
import requests
requests.get("https://api.telegram.org", timeout=5)
print("ok")
PY
  then
    echo "[entrypoint] Network ready (${i}s)"
    break
  fi
  sleep 2
done

echo "[entrypoint] Starting TeamDev HostBot..."
exec python /app/bot.py

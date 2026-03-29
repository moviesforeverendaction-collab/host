#!/bin/bash
set -e

STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
DOCKER_DATA="${STORAGE_ROOT}/docker"
LOG_DIR="${STORAGE_ROOT}/logs"

echo "[entrypoint] Storage root : $STORAGE_ROOT"
echo "[entrypoint] Docker data  : $DOCKER_DATA"

mkdir -p "$DOCKER_DATA" "$LOG_DIR" "$STORAGE_ROOT/data"

# ── Write dockerd config ──────────────────────────────────────────────────────
# Railway runs inside Podman — bridge creation and iptables are blocked.
# We use "host" networking for all user containers (set in docker_manager/vps_manager).
# We do NOT set --bridge=none because that also kills the main container's network.
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

DOCKERD_PID=$!

echo "[entrypoint] Waiting for Docker daemon..."
for i in $(seq 1 90); do
    if docker info > /dev/null 2>&1; then
        echo "[entrypoint] Docker ready (${i}s)"
        break
    fi
    if [ $i -eq 90 ]; then
        echo "[entrypoint] ERROR: Docker daemon did not start. Log:"
        tail -40 "$LOG_DIR/dockerd.log" || true
        exit 1
    fi
    sleep 1
done

# ── Pre-build VPS base image ──────────────────────────────────────────────────
if ! docker image inspect telegram-bot-vps-base > /dev/null 2>&1; then
    echo "[entrypoint] Building VPS base image (first boot ~3 min)..."
    docker build \
        --network=host \
        -t telegram-bot-vps-base \
        -f /app/Dockerfile.vps \
        /app \
        >> "$LOG_DIR/vps-image-build.log" 2>&1 \
    && echo "[entrypoint] VPS base image built." \
    || {
        echo "[entrypoint] WARNING: VPS base image build failed:"
        tail -20 "$LOG_DIR/vps-image-build.log" || true
    }
else
    echo "[entrypoint] VPS base image cached — skipping build."
fi

echo "[entrypoint] Starting TeamDev HostBot..."
exec python /app/bot.py

#!/bin/bash
set -e

STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
DOCKER_DATA="${STORAGE_ROOT}/docker"
LOG_DIR="${STORAGE_ROOT}/logs"

echo "[entrypoint] Storage root : $STORAGE_ROOT"
echo "[entrypoint] Docker data  : $DOCKER_DATA"

mkdir -p "$DOCKER_DATA" "$LOG_DIR" "$STORAGE_ROOT/data"

# ── Start dockerd ─────────────────────────────────────────────────────────────
# Railway uses Podman internally — bridge networking and iptables are blocked.
# --bridge=none     : skip default bridge network creation (needs netns ops)
# --iptables=false  : don't touch iptables (blocked)
# --ip6tables=false : don't touch ip6tables (blocked)
# --ip-masq=false   : don't set up IP masquerading (blocked)
# --storage-driver=vfs : overlay2 needs kernel features not available here
# Containers will run with network_mode=host (set in docker_manager/vps_manager)
echo "[entrypoint] Starting Docker daemon..."
dockerd \
    --host=unix:///var/run/docker.sock \
    --data-root="$DOCKER_DATA" \
    --storage-driver=vfs \
    --bridge=none \
    --iptables=false \
    --ip6tables=false \
    --ip-masq=false \
    --log-level=warn \
    > "$LOG_DIR/dockerd.log" 2>&1 &

DOCKERD_PID=$!

echo "[entrypoint] Waiting for Docker daemon..."
for i in $(seq 1 90); do
    if docker info > /dev/null 2>&1; then
        echo "[entrypoint] Docker ready (${i}s)"
        break
    fi
    if [ $i -eq 90 ]; then
        echo "[entrypoint] ERROR: Docker daemon did not start. Log:"
        tail -30 "$LOG_DIR/dockerd.log" || true
        exit 1
    fi
    sleep 1
done

# ── Pre-build VPS base image ──────────────────────────────────────────────────
if ! docker image inspect telegram-bot-vps-base > /dev/null 2>&1; then
    echo "[entrypoint] Building VPS base image (first boot ~2 min)..."
    docker build \
        -t telegram-bot-vps-base \
        -f /app/Dockerfile.vps \
        /app \
        > "$LOG_DIR/vps-image-build.log" 2>&1 \
    && echo "[entrypoint] VPS base image built." \
    || echo "[entrypoint] WARNING: VPS base image build failed — see $LOG_DIR/vps-image-build.log"
else
    echo "[entrypoint] VPS base image cached — skipping build."
fi

echo "[entrypoint] Starting TeamDev HostBot..."
exec python /app/bot.py

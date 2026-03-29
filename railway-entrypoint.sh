#!/bin/bash
set -e

STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
DOCKER_DATA="${STORAGE_ROOT}/docker"
LOG_DIR="${STORAGE_ROOT}/logs"

echo "[entrypoint] Storage root : $STORAGE_ROOT"
echo "[entrypoint] Docker data  : $DOCKER_DATA"

# Ensure directories exist (volume may be freshly mounted)
mkdir -p "$DOCKER_DATA" "$LOG_DIR" "$STORAGE_ROOT/data"

# ── Start Docker daemon ───────────────────────────────────────────────────────
# overlay2 is blocked in Railway's nested container environment.
# vfs works everywhere without kernel overlay or mount propagation support.
echo "[entrypoint] Starting Docker daemon (driver=vfs, data-root=$DOCKER_DATA)..."
dockerd \
    --host=unix:///var/run/docker.sock \
    --data-root="$DOCKER_DATA" \
    --storage-driver=vfs \
    --iptables=false \
    --ip-masq=false \
    --log-level=warn \
    > "$LOG_DIR/dockerd.log" 2>&1 &

DOCKERD_PID=$!

# Wait for Docker socket to be ready (up to 90 s)
echo "[entrypoint] Waiting for Docker daemon to be ready..."
for i in $(seq 1 90); do
    if docker info > /dev/null 2>&1; then
        echo "[entrypoint] Docker daemon is ready (${i}s)"
        break
    fi
    if [ $i -eq 90 ]; then
        echo "[entrypoint] ERROR: Docker daemon did not start in time. Dumping log:"
        tail -30 "$LOG_DIR/dockerd.log" || true
        exit 1
    fi
    sleep 1
done

# ── Pre-build the VPS base image if not already cached ───────────────────────
if ! docker image inspect telegram-bot-vps-base > /dev/null 2>&1; then
    echo "[entrypoint] Building VPS base image (first boot — ~2 min)..."
    docker build \
        -t telegram-bot-vps-base \
        -f /app/Dockerfile.vps \
        /app \
        > "$LOG_DIR/vps-image-build.log" 2>&1 \
    && echo "[entrypoint] VPS base image built." \
    || echo "[entrypoint] WARNING: VPS base image build failed — check $LOG_DIR/vps-image-build.log"
else
    echo "[entrypoint] VPS base image already cached — skipping build."
fi

# ── Launch the bot ────────────────────────────────────────────────────────────
echo "[entrypoint] Starting TeamDev HostBot..."
exec python /app/bot.py

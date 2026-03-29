#!/bin/bash
set -e

STORAGE_ROOT="${STORAGE_ROOT:-/storage}"
LOG_DIR="${STORAGE_ROOT}/logs"

echo "[entrypoint] Storage root : $STORAGE_ROOT"
mkdir -p "$LOG_DIR" "$STORAGE_ROOT/data"

# If a stale pid exists, remove it so we don't get:
# "process with PID 5 is still running"
rm -f /var/run/docker.pid 2>/dev/null || true

# Do NOT start dockerd on Railway if it is already failing there.
# Start the bot directly and let the bot retry Telegram itself.

echo "[entrypoint] Waiting for network..."
for i in $(seq 1 30); do
    if curl -fsS --max-time 5 https://api.telegram.org >/dev/null 2>&1; then
        echo "[entrypoint] Network ready (${i}s)"
        break
    fi
    sleep 2
done

echo "[entrypoint] Starting TeamDev HostBot..."
exec python /app/bot.py

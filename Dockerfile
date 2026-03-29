# ── TeamDev HostBot — Railway-compatible Dockerfile ─────────────────────────
# NOTE: VOLUME keyword is intentionally absent (Railway does not allow it).
# Mount your Railway persistent disk at /storage in the Railway dashboard.
# Docker data-root is set to /storage/docker so images/containers persist.

FROM python:3.11

ENV DEBIAN_FRONTEND=noninteractive \
    DOCKER_DATA_ROOT=/storage/docker

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        git \
        iptables \
        kmod \
        supervisor \
    && rm -rf /var/lib/apt/lists/*

# ── Install Docker Engine (Docker-in-Docker for Railway) ─────────────────────
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
       | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo \
       "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
       https://download.docker.com/linux/debian \
       $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
       | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       docker-ce \
       docker-ce-cli \
       containerd.io \
       docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

# ── Create required directories (no VOLUME keyword — Railway policy) ──────────
RUN mkdir -p /storage/docker \
             /storage/logs \
             /storage/data \
             /var/run

# ── App setup ─────────────────────────────────────────────────────────────────
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN chmod +x /app/railway-entrypoint.sh /app/vps-entrypoint.sh

ENV PORT=5000
EXPOSE 5000

ENTRYPOINT ["/app/railway-entrypoint.sh"]

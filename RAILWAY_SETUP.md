# TeamDev HostBot — Railway Deployment Guide

## What changed from the original code (logic untouched)

| File | Change |
|---|---|
| `Dockerfile` | Replaced with Railway-compatible version: Docker Engine installed inside image, no `VOLUME` keyword |
| `railway-entrypoint.sh` | **New** — starts `dockerd` (data-root = `/storage/docker`), builds VPS base image on first boot, then runs `bot.py` |
| `railway.toml` | **New** — Railway build/deploy config |
| `github_auth.py` | Flask now reads `PORT` env var (Railway injects this); redirect URI reads `RAILWAY_PUBLIC_DOMAIN` |
| `bot.py` | `tempfile.tempdir` set to `/storage/data` so uploads land on your 1 TB disk |
| `.env.example` | **New** — template of all env vars to paste into Railway |

All bot logic, commands, Docker manager, VPS manager, security scanner, rate limiter, pip manager — **100% unchanged**.

---

## Step 1 — Push code to GitHub

```bash
git init
git add .
git commit -m "Railway deploy"
git remote add origin https://github.com/YOUR_USER/YOUR_REPO.git
git push -u origin main
```

---

## Step 2 — Create Railway project

1. Go to [railway.app](https://railway.app) → **New Project**
2. Choose **Deploy from GitHub repo** → select your repo
3. Railway will detect the `Dockerfile` automatically

---

## Step 3 — Enable Privileged Mode (CRITICAL for Docker-in-Docker)

1. Railway Dashboard → your service → **Settings**
2. Scroll to **Deploy** section
3. Toggle **Privileged mode → ON**

> Without this, `dockerd` cannot start inside the container and the bot will crash.

---

## Step 4 — Mount your 1 TB persistent disk

1. Railway Dashboard → your service → **Volumes** tab (or **+ Add** → **Volume**)
2. Set **Mount path**: `/storage`
3. Set size to whatever Railway allows (your 1 TB plan)

This single mount covers everything:
- `/storage/docker` — all Docker images and containers built by the bot
- `/storage/data`   — user upload temp files
- `/storage/logs`   — dockerd logs

---

## Step 5 — Add environment variables

Railway Dashboard → your service → **Variables** tab → paste each of these:

```
BOT_TOKEN                 = your_telegram_bot_token
MONGODB_URI               = mongodb+srv://...
GITHUB_CLIENT_ID          = your_github_oauth_client_id
GITHUB_CLIENT_SECRET      = your_github_oauth_client_secret
VPS_HOST_IP               = your-app.up.railway.app
```

`PORT` and `RAILWAY_PUBLIC_DOMAIN` are injected automatically by Railway — do not set them.

---

## Step 6 — GitHub OAuth App settings

In your GitHub OAuth App (Settings → Developer Settings → OAuth Apps):

- **Homepage URL**: `https://your-app.up.railway.app`
- **Authorization callback URL**: `https://your-app.up.railway.app/callback`

---

## Step 7 — Deploy

Railway will build and deploy automatically on every push to `main`.  
First boot takes ~3-4 minutes because `dockerd` starts and the VPS base image is built.  
Subsequent boots are fast — the VPS image is cached on your `/storage` disk.

---

## Resource allocation (CPU 32 / RAM 32 GB)

Railway services use all available resources by default.  
You can optionally cap them per service in Settings → Resources.

The bot already respects per-user container limits defined in `bot.py → get_user_limits()`:
- **Free users**: 0.25 CPU cores, 256 MB RAM
- **Premium users**: 2.0 CPU cores, 1024 MB RAM

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Cannot connect to Docker daemon` | Privileged mode not enabled — see Step 3 |
| `No space left on device` | Volume not mounted — see Step 4 |
| GitHub OAuth callback fails | Check RAILWAY_PUBLIC_DOMAIN is auto-set; verify GitHub OAuth App URLs |
| Bot doesn't start at all | Check BOT_TOKEN and MONGODB_URI are set in Variables |
| VPS base image missing | Automatic on first boot — check `/storage/logs/vps-image-build.log` |

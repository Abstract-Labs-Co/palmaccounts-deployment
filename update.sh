#!/bin/bash
# Manual update: no Watchtower/Traefik auto-updater here (it never worked reliably).
# Run this by hand, or wire it into your own cron/schedule, whenever you want this
# site to pick up new images for the tags set in .env (API_TAG, ERP_TAG, POS_TAG,
# PLATFORM_TAG).
set -euo pipefail
cd "$(dirname "$0")"

echo "Pulling latest images for configured tags..."
docker compose pull

echo "Recreating any containers whose image changed..."
docker compose up -d --remove-orphans

docker compose ps

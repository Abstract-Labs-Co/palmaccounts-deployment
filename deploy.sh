#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No .env found. Copying .env.example -> .env"
  cp .env.example .env
  echo
  echo "Edit .env now and set DB_HOST/DB_USER/DB_PASSWORD, JWT_KEY and LAN_HOST for this site,"
  echo "then re-run ./deploy.sh."
  exit 1
fi

echo "Pulling images..."
docker compose pull

echo "Starting stack..."
docker compose up -d

echo
docker compose ps
echo
echo "API:      http://localhost:$(grep -E '^API_PORT=' .env | cut -d= -f2 || echo 5000)"
echo "POS:      http://localhost:$(grep -E '^POS_PORT=' .env | cut -d= -f2 || echo 3002)"
echo "ERP:      http://localhost:$(grep -E '^ERP_PORT=' .env | cut -d= -f2 || echo 3003)"
echo "Platform: http://localhost:$(grep -E '^PLATFORM_PORT=' .env | cut -d= -f2 || echo 3004)"

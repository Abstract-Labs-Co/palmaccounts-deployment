#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Container status:"
docker compose ps

echo
echo "Resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo
echo "API health endpoint:"
API_PORT=$(grep -E '^API_PORT=' .env 2>/dev/null | cut -d= -f2 || echo 5000)
curl -fsS "http://localhost:${API_PORT}/health" && echo || echo "API health check failed"

echo
echo "Disk usage:"
docker system df

echo
echo "Last updated: $(date)"

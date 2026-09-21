#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

usage() {
  cat <<EOF
Usage: $0 <command> [service]

Commands:
  status              Show container status
  logs <service>      Tail logs for a service (api, pos, erp, platform, redis)
  restart [service]   Restart one service, or all if omitted
  stop                Stop the stack (containers stay stopped until 'start')
  start               Start a previously stopped stack
  down                Stop and remove containers (data volumes are untouched)
EOF
}

case "${1:-}" in
  status)
    docker compose ps
    ;;
  logs)
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 logs <service>"
      docker compose config --services
      exit 1
    fi
    docker compose logs -f --tail 200 "$2"
    ;;
  restart)
    if [ -z "${2:-}" ]; then
      docker compose restart
    else
      docker compose restart "$2"
    fi
    ;;
  stop)
    docker compose stop
    ;;
  start)
    docker compose start
    ;;
  down)
    docker compose down
    ;;
  *)
    usage
    exit 1
    ;;
esac

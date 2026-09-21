# Palm On-Prem Deployment

Docker Compose stack for running the latest PalmAccounts stack (dotnet API, ERP,
POS, Platform) on a single on-prem machine, with no Traefik and no
Watchtower/auto-update watchdog. Both were tried before and never worked
reliably, so this branch deliberately keeps things simple: plain `docker
compose`, Docker's own restart policies for auto-start, and manual, explicit
updates.

## Architecture

- **api** — the .NET backend (`fixerug/palmaccounts-v1-prod-api`), talks to
  Postgres and a local Redis cache.
- **erp**, **pos**, **platform** — the Angular frontends, served by nginx.
  Each proxies `/api/*` straight to the `api` container over plain HTTP on the
  Docker network (see "Why custom nginx configs" below).
- **redis** — local cache for the API. Not persisted; losing it just means a
  cold cache, nothing durable lives there.
- **Postgres is not part of this stack.** It must already be running on this
  host (outside Docker) or reachable elsewhere on the network, and is
  administered independently (backups, upgrades, tuning are out of scope
  here).

## Why custom nginx configs

The ERP/POS/Platform images ship with a built-in entrypoint that requires an
`API_UPSTREAM` hostname and always proxies to it over HTTPS
(`proxy_pass https://$api_upstream`). That's built for the cloud/Dokploy setup
where TLS already terminates in front of the container. On a bare on-prem box
there's no TLS in front of anything, so this stack skips that entrypoint
(`entrypoint: ["nginx", "-g", "daemon off;"]`) and mounts a plain-HTTP nginx
config (`nginx/erp.conf`, `nginx/pos.conf`, `nginx/platform.conf`) that talks
to `http://api:8080` directly over the Docker network instead. If you ever put
this box behind real TLS, you can drop back to the stock image behavior by
removing the `entrypoint:`/`volumes:` overrides and setting `API_UPSTREAM`.

## Prerequisites

- Docker Engine with the Compose plugin (`docker compose version`).
- Docker's own service enabled at boot, so containers with `restart:
  unless-stopped` come back up after a reboot:
  ```bash
  sudo systemctl enable docker
  ```
- Postgres already running and reachable from this host, with the
  `palmaccounts_global` database and a role for the API created ahead of
  time.

## First deploy

```bash
cp .env.example .env
# edit .env: DB_HOST/DB_USER/DB_PASSWORD, JWT_KEY, LAN_HOST
./deploy.sh
```

`LAN_HOST` is the address other machines on site use to reach this box (e.g.
its LAN IP) — it's used to build the CORS allow-list for the API so the
frontends can call it from other machines, not just from the box itself.

Default ports (override in `.env` if any collide with something else on the
host):

| Service  | Port |
| -------- | ---- |
| API      | 5000 |
| POS      | 3002 |
| ERP      | 3003 |
| Platform | 3004 |

## Auto-start / restart

Every container in this stack runs with `restart: unless-stopped`: Docker
restarts a crashed container automatically, and restarts the whole stack when
the Docker daemon comes up (e.g. after a reboot), but a container you stop
on purpose (`docker compose stop`, or `./manage.sh stop`) stays stopped until
you start it again. There's no separate supervisor, health-triggered
restarter, or reverse proxy watching over this — just Docker's built-in
policy, which is the piece that actually keeps working.

## Updating

There is no auto-updater. Pull and redeploy new images by hand (or from your
own cron/schedule) with:

```bash
./update.sh
```

This pulls whatever image tag each service is pinned to in `.env`
(`API_TAG`, `ERP_TAG`, `POS_TAG`, `PLATFORM_TAG` — default `v1-prod`, which
always tracks the latest `palm-prod-v1` build from the `deploy-palm-prod-v1`
GitHub Actions workflow) and recreates any container whose image changed. To
hold a site back from an update, pin the relevant `*_TAG` to a specific
`release_version` tag from that workflow's run instead of `v1-prod`.

## Day-to-day management

```bash
./manage.sh status            # container status
./manage.sh logs api          # tail logs for one service
./manage.sh restart pos       # restart one service
./manage.sh stop              # stop everything (won't auto-restart until you start it)
./manage.sh start             # start a previously stopped stack
./health-check.sh             # quick status + API health check + resource usage
```

## File layout

```
docker-compose.yml   # the stack: redis, api, erp, pos, platform
nginx/               # plain-HTTP nginx configs for erp/pos/platform (see above)
.env.example          # copy to .env and fill in per-site values
deploy.sh            # first deploy / bring the stack up
update.sh            # manual image pull + redeploy
manage.sh            # status/logs/restart/stop/start
health-check.sh      # quick health snapshot
```

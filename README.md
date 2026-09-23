# Palm On-Prem Deployment

Docker Compose stack for running the latest PalmAccounts stack (dotnet API, ERP,
POS, Platform, Palm Cafe) on a single on-prem machine, with no Traefik and no
Watchtower/auto-update watchdog. Both were tried before and never worked
reliably, so this branch deliberately keeps things simple: plain `docker
compose`, Docker's own restart policies for auto-start, and manual, explicit
updates.

**Temporary:** this stack currently pulls the `new-palm-test-branch` test
images (built by `deploy-new-palm-test-branch.yml`), not the `palm-prod-v1`
images, so on-prem testing can track the test branch. See "Updating" below
for the image/tag details and how to switch back to prod images later.

## Where this lives

The source of truth is the `on-prem-deployment/` folder of the main
`palmaccounts` repo, next to the app code. Change it there, then publish it to
this repo's `on-prem` branch (which sites `git pull` from):

```bash
git subtree push --prefix=on-prem-deployment \
  https://github.com/Abstract-Labs-Co/palmaccounts-deployment.git on-prem
```

Don't edit the `on-prem` branch directly; the next subtree push would have to
merge it back.

## Architecture

- **api** — the .NET backend (`fixerug/palmaccounts-v1-prod-api`), talks to
  Postgres and a local Redis cache.
- **erp**, **pos**, **platform**, **palm-cafe** — the Angular frontends,
  served by nginx. Each proxies `/api/*` straight to the `api` container over
  plain HTTP on the Docker network (see "Why custom nginx configs" below).
- **redis** — local cache for the API. Not persisted; losing it just means a
  cold cache, nothing durable lives there.
- **Postgres is not part of this stack.** It must already be running on this
  host (outside Docker) or reachable elsewhere on the network, and is
  administered independently (backups, upgrades, tuning are out of scope
  here).

## Why custom nginx configs

The ERP/POS/Platform/Palm Cafe images ship with a built-in entrypoint that
requires an `API_UPSTREAM` hostname and always proxies to it over HTTPS
(`proxy_pass https://$api_upstream`). That's built for the cloud/Dokploy setup
where TLS already terminates in front of the container. On a bare on-prem box
there's no TLS in front of anything, so this stack skips that entrypoint
(`entrypoint: ["nginx", "-g", "daemon off;"]`) and mounts a plain-HTTP nginx
config (`nginx/erp.conf`, `nginx/pos.conf`, `nginx/platform.conf`,
`nginx/palm-cafe.conf`) that talks to `http://api:8080` directly over the
Docker network instead. If you ever put this box behind real TLS, you can
drop back to the stock image behavior by removing the `entrypoint:`/`volumes:`
overrides and setting `API_UPSTREAM`.

## Why the API sets `Auth__Cookie__Secure=false`

The API keeps the session in an httpOnly refresh-token cookie. Browsers refuse
to store a cookie marked `Secure` when it arrives over plain HTTP, and only
`localhost` counts as trustworthy without TLS. A LAN address like
`http://192.168.1.100:3003` does not. Without this setting, users were sent
back to the login page on every reload or new tab. The trade-off is that the
refresh token travels in clear on the LAN, which is acceptable for a
LAN-only box but not for anything reachable from outside. The API logs a
warning at startup while it is set. If you put the box behind real TLS,
remove the setting.

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

| Service   | Port |
| --------- | ---- |
| API       | 5000 |
| POS       | 3002 |
| ERP       | 3003 |
| Platform  | 3004 |
| Palm Cafe | 3005 |

## Auto-start / restart

Every container in this stack runs with `restart: unless-stopped`: Docker
restarts a crashed container automatically, and restarts the whole stack when
the Docker daemon comes up (e.g. after a reboot), but a container you stop
on purpose (`docker compose stop`, or `./manage.sh stop`) stays stopped until
you start it again. There's no separate supervisor, health-triggered
restarter, or reverse proxy watching over this — just Docker's built-in
policy, which is the piece that actually keeps working.

## Updating

There is no Watchtower-style auto-updater watching the registry (that's the
piece that never worked reliably). Instead, pull and redeploy new images with:

```bash
./update.sh
```

This pulls whatever image tag each service is pinned to in `.env`
(`API_TAG`, `ERP_TAG`, `POS_TAG`, `PLATFORM_TAG`, `PALM_CAFE_TAG`) and
recreates any container whose image changed.

Right now the images in `docker-compose.yml` point at the
`new-palm-test-branch` test repos, not the prod ones:

| Service   | Image                                     | Floating tag    |
| --------- | ------------------------------------------ | --------------- |
| api       | `fixerug/palmaccounts-new-test-api`         | `new-test-api`  |
| erp       | `fixerug/palmaccounts-new-erp-test`         | `new-test-api`  |
| pos       | `fixerug/palmaccounts-new-pos-test`         | `new-test-api`  |
| platform  | `fixerug/palmaccounts-new-platform-test`    | `new-test-api`  |
| palm-cafe | `fixerug/palmaccounts-new-palm-cafe-test`   | `new-test-api`  |

These are built by `deploy-new-palm-test-branch.yml` and update on every
push to `new-palm-test-branch`. To hold a site back from an update, pin the
relevant `*_TAG` in `.env` to a specific `release_version` tag from that
workflow's run instead of `new-test-api`.

To move this stack back to the production `palm-prod-v1` images later,
change each `image:` line in `docker-compose.yml` back to the
`fixerug/palmaccounts-v1-prod-*` repos (see the workflow at
`deploy-palm-prod-v1.yml`) and set the `*_TAG` defaults back to `v1-prod`.

### Running it on a schedule

To have this happen automatically instead of by hand, install a host cron job
that just calls the same `update.sh`:

```bash
./install-update-cron.sh              # defaults to 03:00 daily
./install-update-cron.sh "0 */6 * * *"  # or pick your own cron schedule
```

This is plain `cron` calling a script that already works standalone — no
extra container, no Docker socket exposure, no registry-polling daemon to
silently fall over. Output goes to `logs/update.log`. Re-running
`install-update-cron.sh` replaces its own previous entry rather than
stacking duplicates. To remove it, run `crontab -e` and delete the line
tagged `palm-on-prem-update`.

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
docker-compose.yml     # the stack: redis, api, erp, pos, platform, palm-cafe
nginx/                 # plain-HTTP nginx configs for erp/pos/platform/palm-cafe (see above)
.env.example           # copy to .env and fill in per-site values
deploy.sh              # first deploy / bring the stack up
update.sh              # manual image pull + redeploy
install-update-cron.sh # installs a cron job that runs update.sh on a schedule
manage.sh              # status/logs/restart/stop/start
health-check.sh        # quick health snapshot
```

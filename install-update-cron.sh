#!/bin/bash
# Installs (or replaces) a cron entry that runs ./update.sh on a schedule.
# Usage: ./install-update-cron.sh ["cron schedule"]
#   Default schedule: 0 3 * * *  (03:00 daily)
#
# Safe to re-run: it replaces its own previous entry rather than stacking
# duplicates, identified by the TAG comment below.
set -euo pipefail
cd "$(dirname "$0")"
REPO_DIR="$(pwd)"
SCHEDULE="${1:-0 3 * * *}"
TAG="# palm-on-prem-update ($REPO_DIR)"
mkdir -p logs

CMD="cd $REPO_DIR && ./update.sh >> $REPO_DIR/logs/update.log 2>&1"
ENTRY="$SCHEDULE $CMD $TAG"

( crontab -l 2>/dev/null | grep -vF "$TAG" ; echo "$ENTRY" ) | crontab -

echo "Installed cron entry:"
crontab -l | grep -F "$TAG"
echo
echo "Update logs will be appended to $REPO_DIR/logs/update.log"
echo "To remove it later: crontab -e, and delete the line tagged '$TAG'"

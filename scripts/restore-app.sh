#!/usr/bin/env bash
# ============================================================================
# restore-app.sh <app-name> <backup-dir>
#
# Example: ./restore-app.sh authentik ./backups/authentik-20260819-101500
#
# Run this AFTER `docker compose up -d` on the new host has created empty
# volumes and an initialized (but empty) database. This script fills them
# in from a backup produced by backup-app.sh.
# ============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck disable=SC1090
source "${SCRIPT_DIR}/lib-backup-restore.sh"
# shellcheck disable=SC1091
source "${KIT_DIR}/.env"

app="${1:?Usage: restore-app.sh <app-name> <backup-dir>}"
in_dir="${2:?Usage: restore-app.sh <app-name> <backup-dir>}"
conf="${KIT_DIR}/templates/${app}/backup.conf"
require_conf "$conf"

[ -d "$in_dir" ] || die "Backup dir not found: $in_dir"

log "Restoring ${APP_NAME} from ${in_dir}"
echo "This will write into the currently running containers for ${APP_NAME}."
read -r -p "Type the app name (${APP_NAME}) to confirm: " confirm
[ "$confirm" = "${APP_NAME}" ] || die "Confirmation did not match, aborting."

untar_volumes "$in_dir"
dump_present=$(ls "${in_dir}/${APP_NAME}-db.sql" 2>/dev/null || true)
if [ -n "$dump_present" ]; then
  restore_database "$in_dir"
else
  log "No DB dump file found, skipping DB restore (expected if DB_TYPE=none)"
fi

log "Restore complete. Now check app-specific post-restore steps in docs/app-notes-${APP_NAME}.md"

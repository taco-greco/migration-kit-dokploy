#!/usr/bin/env bash
# ============================================================================
# backup-app.sh <app-name>
#
# Example: ./backup-app.sh authentik
#
# Reads templates/<app-name>/backup.conf, dumps the DB (if any) with a
# logical dump, tars up named volumes, and (optionally) ships the result
# off-box via rsync or S3 as configured in .env.
# ============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_DIR="$(dirname "$SCRIPT_DIR")"

# shellcheck disable=SC1090
source "${SCRIPT_DIR}/lib-backup-restore.sh"
# shellcheck disable=SC1091
source "${KIT_DIR}/.env"

app="${1:?Usage: backup-app.sh <app-name>  (e.g. authentik, glpi, nextcloud)}"
conf="${KIT_DIR}/templates/${app}/backup.conf"
require_conf "$conf"

out_dir="${KIT_DIR}/backups/${APP_NAME}-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out_dir"

log "Backing up ${APP_NAME} into ${out_dir}"
dump_database "$out_dir"
tar_volumes "$out_dir"
ship_backup "$out_dir"

log "Done. Local copy kept at: ${out_dir}"
log "Verify the .sql file is non-empty and the .tar.gz files are readable before wiping the old host:"
ls -lh "$out_dir"

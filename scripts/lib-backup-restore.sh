#!/usr/bin/env bash
# ============================================================================
# lib-backup-restore.sh
# Shared functions used by backup-app.sh and restore-app.sh.
# Not meant to be run directly.
#
# Design choice: for the DB, we always use a logical dump (pg_dump /
# mysqldump) rather than copying the raw data directory or Docker volume.
# Raw volume copies between hosts are what broke the Authentik migration
# reported in https://github.com/goauthentik/authentik/discussions/7511 —
# ownership/UID and Postgres version mismatches between hosts silently
# corrupt or ignore the copied files. A logical dump avoids all of that.
# Named volumes that are NOT a database (media, uploads, config) are backed
# up as tar archives, which is safe.
# ============================================================================

log()  { echo "[$(date +%H:%M:%S)] $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }

require_conf() {
  local conf="$1"
  [ -f "$conf" ] || die "Missing app config: $conf"
  # shellcheck disable=SC1090
  source "$conf"
  : "${APP_NAME:?APP_NAME not set in $conf}"
  : "${DB_TYPE:?DB_TYPE not set in $conf}"   # postgres | mysql | none
}

dump_database() {
  local out_dir="$1"
  case "$DB_TYPE" in
    postgres)
      log "Dumping Postgres database '${DB_NAME}' from container ${DB_CONTAINER}..."
      docker exec "$DB_CONTAINER" pg_dump -U "${DB_USER}" "${DB_NAME}" \
        > "${out_dir}/${APP_NAME}-db.sql"
      ;;
    mysql)
      log "Dumping MySQL/MariaDB database '${DB_NAME}' from container ${DB_CONTAINER}..."
      docker exec "$DB_CONTAINER" sh -c \
        "mysqldump -u${DB_USER} -p\${MYSQL_PASSWORD:-\$MARIADB_PASSWORD} ${DB_NAME}" \
        > "${out_dir}/${APP_NAME}-db.sql"
      ;;
    none)
      log "DB_TYPE=none, skipping database dump for ${APP_NAME}"
      ;;
    *)
      die "Unknown DB_TYPE '${DB_TYPE}'"
      ;;
  esac
}

restore_database() {
  local in_dir="$1"
  case "$DB_TYPE" in
    postgres)
      log "Restoring Postgres database '${DB_NAME}' into container ${DB_CONTAINER}..."
      cat "${in_dir}/${APP_NAME}-db.sql" | docker exec -i "$DB_CONTAINER" \
        psql -U "${DB_USER}" "${DB_NAME}"
      ;;
    mysql)
      log "Restoring MySQL/MariaDB database '${DB_NAME}' into container ${DB_CONTAINER}..."
      cat "${in_dir}/${APP_NAME}-db.sql" | docker exec -i "$DB_CONTAINER" sh -c \
        "mysql -u${DB_USER} -p\${MYSQL_PASSWORD:-\$MARIADB_PASSWORD} ${DB_NAME}"
      ;;
    none) log "DB_TYPE=none, skipping database restore for ${APP_NAME}" ;;
    *) die "Unknown DB_TYPE '${DB_TYPE}'" ;;
  esac
}

tar_volumes() {
  local out_dir="$1"
  for vol in "${VOLUMES[@]}"; do
    log "Archiving named volume '${vol}'..."
    docker run --rm \
      -v "${vol}:/data:ro" \
      -v "${out_dir}:/backup" \
      alpine \
      tar czf "/backup/${vol}.tar.gz" -C /data .
  done
}

untar_volumes() {
  local in_dir="$1"
  for vol in "${VOLUMES[@]}"; do
    [ -f "${in_dir}/${vol}.tar.gz" ] || { log "No archive for volume ${vol}, skipping"; continue; }
    log "Restoring named volume '${vol}' (volume must already exist / be created by docker compose up)..."
    docker run --rm \
      -v "${vol}:/data" \
      -v "${in_dir}:/backup" \
      alpine \
      sh -c "cd /data && tar xzf /backup/${vol}.tar.gz"
  done
}

ship_backup() {
  local local_dir="$1"
  case "${BACKUP_METHOD:-rsync}" in
    rsync)
      [ -n "${BACKUP_SSH_TARGET:-}" ] || { log "BACKUP_SSH_TARGET not set, leaving backup only in ${local_dir}"; return; }
      log "Shipping backup to ${BACKUP_SSH_TARGET}..."
      rsync -avz "${local_dir}/" "${BACKUP_SSH_TARGET}/${APP_NAME}/"
      ;;
    s3)
      : "${S3_BUCKET:?S3_BUCKET required for BACKUP_METHOD=s3}"
      log "Shipping backup to s3://${S3_BUCKET}/${APP_NAME}/ ..."
      aws --endpoint-url "${S3_ENDPOINT}" s3 cp "${local_dir}" \
        "s3://${S3_BUCKET}/${APP_NAME}/" --recursive
      ;;
    *) die "Unknown BACKUP_METHOD '${BACKUP_METHOD:-}'" ;;
  esac
}

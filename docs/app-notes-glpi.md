# GLPI — migration notes

## Must preserve
- The MySQL/MariaDB database (asset records, tickets, users) — logical dump via `mysqldump`.
- `glpi-files` (attachments, uploaded documents) and `glpi-config` (`config_db.php` etc. if not baked into the image).

## Procedure
1. Confirm which image/Dockerfile you're actually running today: `docker inspect <glpi-container> --format '{{.Config.Image}}'`. If it's a custom build, copy your real Dockerfile into `templates/glpi/` and switch the compose file to `build: .`.
2. Update `templates/glpi/backup.conf` `DB_CONTAINER` to match `docker ps` on the old host.
3. `scripts/backup-app.sh glpi` on the old host.
4. Bring the new host up (`docker compose up -d` / Dokploy deploy) so the DB container initializes and the app is reachable — GLPI's setup wizard may run once against the empty DB, that's fine, it'll be overwritten by the restore.
5. `scripts/restore-app.sh glpi <backup-dir>`.
6. Log in with an existing GLPI account to confirm the restore worked, and check the `files` directory (attachments) actually shows up on a ticket that had one.

## Config gotcha
If `config_db.php` (DB host/credentials) was baked directly into the image rather than templated via env vars, it'll need a manual edit after restore since the new DB container's hostname inside the compose network may differ. Check `glpi-config` contents after restore before assuming it "just works."

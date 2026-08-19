# Nextcloud — migration notes

You already said this one is low-stakes ("apart from some basic settings we haven't done much," and it's fine even if the DB doesn't fully come across). Given that, don't over-invest here — a clean reinstall is a perfectly acceptable fallback if the restore is fussy.

## Recommended approach: try the real migration, but set a time box
1. `scripts/backup-app.sh nextcloud` on the old host (this dumps the DB and tars `nextcloud-data`, per `templates/nextcloud/backup.conf`).
2. On the new host, `docker compose up -d` to get a fresh install running.
3. Put the new instance into maintenance mode before restoring:
   `docker compose exec app php occ maintenance:mode --on`
4. `scripts/restore-app.sh nextcloud <backup-dir>` (restores `nextcloud-data`; DB_TYPE is mysql, so the dump also restores if you kept `DB_TYPE=mysql` and filled in `DB_CONTAINER`).
5. Update `NEXTCLOUD_TRUSTED_DOMAINS` in `templates/nextcloud/.env` to the new host's IP (step 2) or `cloud.${BASE_DOMAIN}` (step 3).
6. `docker compose exec app php occ maintenance:mode --off`, then log in and check a file you know existed before.

## If it doesn't come across cleanly
Per the official Nextcloud migration doc, `data-fingerprint` and trusted_domains are the two things that most commonly cause a "looks empty / login loop" after a restore. If step 6 doesn't work within, say, 30 minutes of troubleshooting, it's genuinely fine to `docker compose down -v` the new instance and start Nextcloud fresh — reconnect it to Authentik the same basic way you did before, and move on. This app is explicitly not worth burning the whole afternoon on.

# Authentik — migration notes

You said the Authentik setup so far is "really basic" (connected to it, nothing fancy). That's good — it caps the blast radius if something doesn't restore perfectly, but the two things below are still worth getting right because if they're wrong, nobody can log into anything else that depends on Authentik.

## Must preserve exactly
- **`AUTHENTIK_SECRET_KEY`** — copy the exact value from the old install's env vars. It signs sessions and encrypts some stored fields. A new random key silently breaks login even if the DB restores fine.
- **The Postgres data** — via logical dump (`pg_dump`/`psql`), not a raw volume copy. Community reports (see the GitHub discussion linked in `lib-backup-restore.sh`) show raw volume copies between hosts failing silently — the new instance starts, looks healthy, but doesn't actually see the old users/config.

## Nice to preserve
- `authentik-media` (uploaded branding/logos) and `authentik-templates` (custom email/flow templates) — only matters if you customized these; skip if you didn't.
- `authentik-certs` — only matters if you issued certs through Authentik itself (e.g. for an LDAP/RADIUS outpost). If you haven't touched outposts, you can skip this and let it regenerate.

## Procedure
1. On the OLD host: find the running container names (`docker ps`), update `templates/authentik/backup.conf` `DB_CONTAINER` to match, then run `scripts/backup-app.sh authentik`.
2. On the NEW host: fill `templates/authentik/.env` with the **same** `AUTHENTIK_SECRET_KEY` as before, then `docker compose up -d` (or deploy via Dokploy) to create fresh, empty volumes and an initialized DB.
3. Run `scripts/restore-app.sh authentik <backup-dir>`.
4. Log in and spot-check: your existing users/groups are there, and the app(s) you'd connected to Authentik (via OIDC/SAML) still authenticate. If an app was pointed at Authentik by IP, you'll need to update that app's issuer URL once Authentik has a new IP or domain.

## Where this fits in step 3 (real server + domain)
Once Authentik is reachable at `auth.${BASE_DOMAIN}` instead of a bare IP, any app that authenticates against it needs its OIDC/SAML redirect URIs and issuer URL updated to the new hostname — do this for each connected app right after cutover, before anyone tries to log in.

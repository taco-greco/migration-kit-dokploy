# Migration checklist

Print this or keep it open in a second window during the actual run.

## Before you start (once, not per-host)
- [ ] Network admin has given the mini PC a fixed IP/DHCP reservation (see network-admin-message.md) — get this BEFORE deploying anything so `.env` `TARGET_IP` doesn't change under you mid-test.
- [ ] `.env` created from `.env.example`, `TARGET_IP` filled in and confirmed with `hostname -I` on the target box.
- [ ] For each real internal app (PHP/Node), its own folder created under `templates/` (copied from `templates/php-app` or `templates/node-app`) with the real Dockerfile dropped in.

## Step 2 — mini PC test run
- [ ] `scripts/00-preflight-check.sh` passes clean
- [ ] `scripts/01-install-dokploy.sh` completes, admin account created, credentials saved to password manager
- [ ] Authentik: backed up from wherever it's currently running -> restored on mini PC -> login works (see app-notes-authentik.md)
- [ ] GLPI: same (app-notes-glpi.md)
- [ ] NextCloud: same, time-boxed (app-notes-nextcloud.md)
- [ ] Each internal PHP app: deployed from its own compose file, smoke-tested
- [ ] Each internal Express/React app: deployed from its own compose file, smoke-tested
- [ ] Note every manual step you had to do that wasn't already in a script — fold it back into this kit before step 3, that's the whole point of doing step 2 first

## Step 3 — real server (Dell R630)
- [ ] RAID/BIOS/iDRAC sanity-checked, Ubuntu Server installed fresh
- [ ] `.env` `TARGET_IP` updated to the real server's (static) IP
- [ ] `scripts/00-preflight-check.sh` -> `scripts/01-install-dokploy.sh`, same as step 2
- [ ] Domain + SSL configured (see MIGRATION-RUNBOOK.md "Domain & SSL")
- [ ] Each app deployed + restored, same order as step 2
- [ ] OIDC/SAML redirect URIs in every Authentik-connected app updated to the new hostname
- [ ] Old mini-PC test instances torn down or clearly relabeled so nobody mistakes them for prod
- [ ] Backups scheduled going forward (see MIGRATION-RUNBOOK.md "Ongoing backups")

# DevOpsMedia self-hosting migration — runbook

Companion files: `.env.example`, `scripts/`, `templates/`, `docs/`. Everything referenced below lives in this kit.

## 0. On your 3-step plan

Your instinct to test on a mini PC before touching the real server is right, and no need to change the overall shape. The one adjustment worth making: **build step 2 so step 3 is a re-run, not a rewrite.**

Concretely, that means nothing in the scripts or compose files should hardcode "the mini PC's IP" or "no domain yet" — those live in one `.env` file. Step 2 is: fill in `.env` for the mini PC, run the kit, fix whatever breaks, and update the kit (not just your memory) with the fix. Step 3 is: fill in `.env` for the real server, run the *same* kit, and layer on the domain/SSL piece that step 2 deliberately skipped. If step 3 requires you to remember a bunch of manual tweaks you did in step 2 by hand, step 2 didn't do its job — so treat "did I script this or just do it once by hand?" as the test for every action during step 2.

This also directly answers "what to automate": automate everything up to and including getting each app running and holding data correctly. Don't try to automate the domain/SSL/VPN layer during step 2 — you don't have a domain or the real network position yet, and testing it on the mini PC would just be testing against fake conditions. That's the one piece that's genuinely step-3-only.

## 1. Repo layout

```
migration-kit/
  .env.example          -> copy to .env, this is the only file that changes between step 2 and step 3
  scripts/
    00-preflight-check.sh
    01-install-dokploy.sh
    lib-backup-restore.sh
    backup-app.sh <app>
    restore-app.sh <app> <backup-dir>
  templates/
    authentik/  glpi/  nextcloud/   -> compose file + .env.example + backup.conf per app
    php-app/  node-app/             -> generic starting points, copy per real internal app
  docs/
    app-notes-authentik.md / -glpi.md / -nextcloud.md
    migration-checklist.md
    network-admin-message.md
```

Put this whole folder in a private git repo (even just on the mini PC itself, or a private GitHub/Gitea repo) so you have history of what changed between step 2 and step 3. Do **not** commit real `.env` files — only the `.env.example` / per-app `.env.example` templates, since the real ones hold passwords and the Authentik secret key.

## 2. Step 2 — mini PC (today)

1. `cp .env.example .env`, fill in `TARGET_IP` with the mini PC's current IP (`hostname -I`).
2. `./scripts/00-preflight-check.sh` — fixes anything it flags before continuing.
3. `./scripts/01-install-dokploy.sh` — installs Dokploy, prints the setup URL.
4. Open `http://<mini-pc-ip>:3000`, create the admin account, save credentials.
5. For each app (Authentik, GLPI, NextCloud, then your internal apps):
   - Copy the relevant `templates/<app>/.env.example` to `.env` inside that folder, fill in real values.
   - Deploy it — either via Dokploy's UI pointing at `templates/<app>/docker-compose.yml`, or `docker compose up -d` directly in that folder while you're still getting the compose file right, then move it into Dokploy once it's stable.
   - Follow `docs/app-notes-<app>.md` for the backup → restore → verify sequence.
6. Work through `docs/migration-checklist.md` "Step 2" section as you go, and **write down every manual step that wasn't in a script** — that list is exactly what to fix before step 3.

You have no live traffic depending on the mini PC, so this is the cheap place to find out that, say, GLPI's config is baked into the image, or that a particular Docker volume name doesn't match what's in `backup.conf`. Expect to iterate on the `templates/` files themselves during this phase — that's the point of testing here first.

## 3. Backups: how this kit does them, and how Dokploy's built-in backups differ

Two different things, don't conflate them:

- **This kit's `backup-app.sh` / `restore-app.sh`** — a one-time (or repeatable) manual export/import used to *move* an app from wherever it runs now onto the new host. Uses `pg_dump`/`mysqldump` for the database (not raw file copies — see `app-notes-authentik.md` for why that matters) and `tar` for other named volumes. Ships to wherever `BACKUP_METHOD` in `.env` points — plain `rsync` over SSH is enough for a same-LAN move, no need to stand up S3 for this.
- **Dokploy's own scheduled Volume Backups** — a recurring safety net you turn on *after* an app is running on its permanent home, for ongoing disaster recovery. As of the current Dokploy release this only supports **S3-compatible destinations** (not local disk), and only backs up Docker *named volumes* (bind mounts need to be converted to named volumes first, which the templates in this kit already use). For a small setup, a free-tier Cloudflare R2 bucket or a self-hosted MinIO instance (e.g. on the old test PC once it's freed up) both work as the S3 target. Set this up once things land on the real server in step 3 — no need to bother with it on the disposable mini PC.

## 4. Step 3 — real server (Dell R630)

Once the mini PC test has run clean and the kit is updated with every fix you found:

1. Install Ubuntu Server on the R630 (same version you used for testing, ideally).
2. `.env`: update `TARGET_IP` to the server's IP, set `TARGET_IP_IS_STATIC=true` (confirm this with the network admin first — see below), fill in `BASE_DOMAIN` and the DNS provider fields.
3. Run `00-preflight-check.sh` → `01-install-dokploy.sh` — identical commands to step 2.
4. Deploy + restore each app the same way, in the same order, using the backups you took either from the mini PC test data (fine, it's just test data) or fresh from wherever the apps are truly running today if that's different from the mini PC.
5. Now add the layer step 2 skipped: domains + SSL (below), then VPN access notes for remote use.
6. Work through `docs/migration-checklist.md` "Step 3" section, including updating every Authentik-connected app's OIDC/SAML redirect URIs to the new hostname.

### RAID / storage note specific to this hardware
The R630 has 2× 400GB SSDs in hardware RAID 1 via the PERC H730 — that's your redundancy for the OS + Docker volumes living on local disk. It is not a backup. If that RAID array fails at the controller level (not just a single disk), you lose everything on it simultaneously — which is exactly why step 3 also turns on the off-box Dokploy S3 backups in section 3, rather than relying on RAID 1 alone.

## 5. Domain & SSL (step 3 only)

You want real, trusted SSL certificates for an internal-only setup (no public traffic, LAN + VPN access only). The constraint that shapes this: Let's Encrypt's normal HTTP validation requires port 80 reachable from the public internet, which you explicitly don't want to expose. Two workable options:

**Option A — DNS-01 challenge with a domain you control (recommended).**
You (or your company) own a real domain, and delegate a subdomain to it, e.g. `int.yourdomain.com`. Let's Encrypt validates ownership by checking a DNS TXT record via your DNS provider's API (Cloudflare, etc.) — this works even though the server itself is never reachable from the internet. You get real, browser-trusted certs. Then, separately, make `auth.int.yourdomain.com` etc. actually *resolve* to the server's LAN IP for people on the network — this is where your network admin comes back in (see below): either they add internal DNS override entries on the office router/DNS server (cleanest), or, as a fallback, each machine gets a `/etc/hosts` entry (fine for "a handful of people on one LAN," annoying past that). Set `DNS_PROVIDER` / `DNS_API_TOKEN` in `.env` for this.

**Option B — self-signed / internal CA.**
Skip public DNS entirely, generate your own certificate authority (e.g. with `mkcert` or `step-ca`), issue certs signed by it, and install that CA's root cert on each machine that needs to trust it. No dependency on any external DNS provider, fully within your control, but every device needs the CA cert installed once, and remote/VPN users need it too.

Given you already said this is "just for our enterprise" with VPN as the access path for remote people, Option A is worth the one-time setup — it means no per-device CA install, and it composes cleanly with a future OpenVPN/WireGuard setup since VPN clients just need to be pointed at your internal DNS resolver (or have the same hosts entries) to resolve the internal-only domain once they're on the VPN.

## 6. Talk to the network admin

Two things to raise in the meeting you're setting up (draft message in `docs/network-admin-message.md`, ready to send):
1. A fixed IP/DHCP reservation for the new mini PC now, and the real server once it's racked (same thing they already did for the first test PC).
2. How IP rotation currently works on the network generally (so you know whether a reservation is really "set and forget" or needs periodic attention), and — new ask — whether there's an internal DNS server you can add a zone/override to for Option A above, since that's the cleanest way to make `*.int.yourdomain.com` resolve only inside your network.

## 7. VPN access (brief, for later)

Not urgent for step 2 or the first half of step 3 — flagging so it's not forgotten. Once the domain/SSL layer is up, remote access for people off the office LAN needs a VPN (OpenVPN or WireGuard — WireGuard is simpler to set up and has better performance if you don't have a hard requirement for OpenVPN specifically) terminating on the office network, handing out the internal DNS resolver to connected clients so the internal-only hostnames resolve the same way they do on-site. This is naturally a step-3-tail-end task, worth its own short runbook once you're there rather than folding into this one now.

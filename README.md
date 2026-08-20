# DevOpsMedia self-hosting

Migrating our self-hosted apps (Authentik, GLPI, NextCloud, internal PHP/Express+React apps) off ad-hoc setups and onto Dokploy, first on a test mini PC, then on the Dell PowerEdge R630 we bought for production.

## Plan

1. **Install Dokploy** (this repo, `step-1-install-dokploy/`) — get Dokploy running on a host. No IP/domain config needed yet.
2. **Migrate apps on the test mini PC** — deploy + backup/restore each app using reusable, target-agnostic scripts, so nothing here is hardcoded to one machine. Iron out issues here where nothing is production.
3. **Repeat step 2 on the real server**, pointed at its own fixed IP, plus add the internal domain name + SSL + VPN access on top.

Step 1 is done and tested (see below). Steps 2/3 land in this repo as their own folders once ready.

## Step 1 — install Dokploy

```
sudo ./step-1-install-dokploy/install-dokploy.sh
```

Requirements: a fresh Ubuntu or Debian host, run as root/sudo, network access. Nothing else to configure beforehand.

What it does: quick non-blocking sanity checks (RAM/disk/ports), installs Docker CE from Docker's own repo if not already present, then runs Dokploy's official installer. See the comments at the top of the script for why it installs Docker itself rather than leaving that to Dokploy's installer — short version: Dokploy's installer pins an exact Docker version that can be missing on a very new Ubuntu release (bit us on Ubuntu 26.04 "Resolute Raccoon"), so we install Docker ourselves, unpinned, first.

After it finishes, open the printed `http://<host-ip>:3000` and create the admin account.

## Notes

- No `.env` file yet — this step doesn't need one. Config for the actual app migrations (target IP, domain, secrets) comes in step 2/3 once a host has a fixed IP.
- Once the network admin gives a host a fixed IP/DHCP reservation, that host is a candidate for a real, ongoing Dokploy instance rather than a throwaway test.

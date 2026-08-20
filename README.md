# Dokploy bootstrap kit

A small, repeatable toolkit for getting [Dokploy](https://dokploy.com) running on a fresh Ubuntu/Debian host — meant to be proven out on a disposable test host first, then re-run unchanged on a production host.

## Plan

1. **Install Dokploy** (this repo, `step-1-install-dokploy/`) — get Dokploy running on a host. No IP/domain config needed yet.
2. **Deploy and validate on a test host** — deploy the apps you're moving over, back them up, restore them, using reusable, target-agnostic scripts so nothing here is hardcoded to one machine. Iron out issues here where nothing is production.
3. **Repeat step 2 on the production host**, pointed at its own fixed IP, plus add a domain name + SSL + VPN access on top.

Step 1 is done and tested (see below). Steps 2/3 land in this repo as their own folders once ready.

## Step 1 — install Dokploy

```
cd step-1-install-dokploy
sudo bash install-dokploy.sh
```

If this host already has a fixed IP (e.g. a DHCP reservation from your network admin), pin Docker Swarm to it explicitly instead of letting it auto-detect:

```
sudo ADVERTISE_ADDR=<fixed-ip> bash install-dokploy.sh
```

**Run it exactly like that — `sudo bash install-dokploy.sh` — not `sh install-dokploy.sh` and not bare `sudo install-dokploy.sh`.**
- `sh install-dokploy.sh` fails with `Illegal option -o pipefail`: on Ubuntu/Debian, `sh` is `dash`, and the script's `#!/usr/bin/env bash` shebang only takes effect when you execute the file directly — explicitly invoking `sh` overrides it and dash doesn't support the `pipefail` option the script relies on.
- `sudo install-dokploy.sh` (no `./` or path) fails with `command not found`: the shell only looks in `$PATH` for a bare command name, and the current directory isn't in `$PATH` by design.
- `sudo bash install-dokploy.sh` sidesteps both — it forces bash explicitly and doesn't depend on `$PATH` or the file's executable bit.

Requirements: a fresh Ubuntu or Debian host, run as root/sudo, network access. Nothing else to configure beforehand.

What it does: quick non-blocking sanity checks (RAM/disk/ports), installs Docker CE from Docker's own repo if not already present, then runs Dokploy's official installer. See the comments at the top of the script for why it installs Docker itself rather than leaving that to Dokploy's installer — short version: Dokploy's installer pins an exact Docker version, which can be missing on a very new distro release if Docker's repo hasn't built that specific version for it yet (this bit us on a brand-new Ubuntu LTS release), so we install Docker ourselves, unpinned, first. This isn't tied to any particular OS version or to whether the IP is fixed — it can recur on any host where Dokploy's pinned version isn't available yet, so the script always does it as a no-cost safety net.

After it finishes, open the printed `http://<host-ip>:3000` and create the admin account. If you used `ADVERTISE_ADDR`, the script also prints a one-line check to confirm Swarm actually bound to it — Dokploy's handling of that variable has had reported upstream bugs, so it's verified rather than assumed.

## Notes

- No `.env` file yet — this step doesn't need one. Config for actual app deployment/migration (target IP, domain, secrets) comes in step 2/3 once a host has a fixed IP.
- Once a host has a fixed IP/DHCP reservation, it's a candidate for a real, ongoing Dokploy instance rather than a throwaway test — re-run this script with `ADVERTISE_ADDR` set once that happens, since Docker Swarm bakes in whatever address was used at `docker swarm init` time and doesn't like it changing later. If Dokploy is already installed and the IP changes anyway, the fix is `docker swarm init --force-new-cluster --advertise-addr <new-ip>` on a single-manager node — safe on a single node, just disruptive, so better to avoid by getting the reservation first.

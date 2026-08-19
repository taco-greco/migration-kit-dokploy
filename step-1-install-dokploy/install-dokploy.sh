#!/usr/bin/env bash
# ============================================================================
# install-dokploy.sh — Step 1: install Dokploy on a fresh Ubuntu/Debian host
#
# Usage:
#   sudo ./install-dokploy.sh
#
# What this does:
#   1. Quick sanity checks (RAM, disk, ports 80/443/3000 free) — these WARN,
#      they don't block. This is meant to run on a host that's still being
#      provisioned, not gate on a fixed IP or any other config.
#   2. Installs Docker CE directly from Docker's own official apt repo, if
#      it isn't already installed — deliberately WITHOUT pinning a version.
#   3. Runs the official Dokploy installer.
#
# Why step 2 installs Docker itself instead of letting Dokploy's installer
# do it: Dokploy's bundled installer pins an exact Docker version. On a
# brand-new Ubuntu release, Docker's repo may not have that exact version
# built yet even though newer versions exist — this is exactly what happened
# on Ubuntu 26.04 "Resolute Raccoon": Dokploy tried to install Docker
# 28.5.0, which was never published for the "resolute" apt suite (only
# 29.x+ was), so the install silently failed with docker-ce held back and
# no docker binary at all. Installing Docker ourselves first (unpinned, so
# apt just grabs whatever the newest available build is) sidesteps that —
# Dokploy's installer detects Docker is already present and skips its own
# version-pinned install step entirely.
#
# No .env / target IP / domain config here on purpose. That comes later,
# once this host has a fixed IP and we're migrating real apps onto it —
# this script's only job is "get Dokploy running."
# ============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root: sudo $0" >&2
  exit 1
fi

echo "== Quick sanity checks (informational only, won't block) =="
mem_gb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
echo "RAM: ${mem_gb} GB (Dokploy wants >= 2 GB)"
disk_gb=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
echo "Free disk on /: ${disk_gb} GB (Dokploy wants >= 30 GB)"
for p in 80 443 3000; do
  if ss -ltn "( sport = :$p )" 2>/dev/null | grep -q ":$p"; then
    echo "WARNING: port $p is already in use — Dokploy needs it free"
  fi
done
echo

echo "== Docker =="
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "Docker already installed and running ($(docker --version)) — skipping install."
else
  echo "Installing Docker CE from Docker's official repo (latest available for this distro, unpinned)..."
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  # In case a previous failed attempt (e.g. Dokploy's own installer) left
  # these on hold, as happened on the resolute install above — release it.
  apt-mark unhold docker-ce docker-ce-cli docker-ce-rootless-extras >/dev/null 2>&1 || true
  # Deliberately NOT pinning a version here — see header comment.
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "Docker installed: $(docker --version)"
fi
echo

echo "== Installing Dokploy =="
curl -sSL https://dokploy.com/install.sh | sh

echo
echo "If the block above ended with 'Congratulations, Dokploy is installed!',"
echo "open the printed http://<ip>:3000 URL to create the admin account, and"
echo "save that URL + credentials in your password manager now."

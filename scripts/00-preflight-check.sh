#!/usr/bin/env bash
# ============================================================================
# 00-preflight-check.sh
# Run this FIRST on any target host (mini PC or the real R630), before
# installing Dokploy. Fails loudly rather than letting install.sh half-work.
# ============================================================================
set -euo pipefail

if [ -f "$(dirname "$0")/../.env" ]; then
  # shellcheck disable=SC1091
  source "$(dirname "$0")/../.env"
else
  echo "!! No .env found next to this kit. Copy .env.example to .env first." >&2
  exit 1
fi

fail=0
ok()   { echo "  [OK]   $1"; }
warn() { echo "  [WARN] $1"; }
bad()  { echo "  [FAIL] $1"; fail=1; }

echo "== OS / architecture =="
if grep -qiE 'ubuntu|debian' /etc/os-release; then ok "Supported distro: $(. /etc/os-release; echo "$PRETTY_NAME")"; else warn "Unrecognized distro, Dokploy supports Ubuntu/Debian/Fedora/CentOS"; fi

echo "== Resources =="
mem_gb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
[ "$mem_gb" -ge 2 ] && ok "RAM: ${mem_gb} GB (>= 2 GB required)" || bad "RAM: ${mem_gb} GB (< 2 GB minimum)"

disk_gb=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
[ "$disk_gb" -ge 30 ] && ok "Free disk on /: ${disk_gb} GB (>= 30 GB required)" || bad "Free disk on /: ${disk_gb} GB (< 30 GB minimum)"

echo "== Ports free (80, 443, 3000) =="
for p in 80 443 3000; do
  if ss -ltn "( sport = :$p )" | grep -q ":$p"; then
    bad "Port $p is already in use"
  else
    ok "Port $p free"
  fi
done

echo "== Network =="
current_ip=$(hostname -I | awk '{print $1}')
echo "  Detected IP right now: ${current_ip}"
echo "  .env TARGET_IP:        ${TARGET_IP:-<unset>}"
if [ "${current_ip}" != "${TARGET_IP:-}" ]; then
  warn "Detected IP does not match TARGET_IP in .env — update .env before deploying anything with a fixed domain/IP reference."
fi
if [ "${TARGET_IP_IS_STATIC:-false}" != "true" ]; then
  warn "TARGET_IP_IS_STATIC is not 'true'. If this box's IP can rotate, Dokploy/domain config will break after a DHCP renewal. Get a reservation from the network admin first (see docs/network-admin-message.md)."
fi

echo "== Docker =="
if command -v docker >/dev/null 2>&1; then
  ok "Docker already installed ($(docker --version))"
else
  warn "Docker not found — install.sh will install it automatically, this is just informational"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "Preflight passed. Safe to run 01-install-dokploy.sh"
else
  echo "Preflight found blocking issues above. Fix them before continuing." >&2
  exit 1
fi

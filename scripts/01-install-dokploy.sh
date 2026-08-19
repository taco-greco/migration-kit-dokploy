#!/usr/bin/env bash
# ============================================================================
# 01-install-dokploy.sh
# Installs Dokploy on the current host using the official install script.
# Same script runs on the test mini PC (step 2) and the real server (step 3)
# — that's the point of this kit: nothing host-specific is hardcoded here.
#
# Docs: https://docs.dokploy.com/docs/core/installation
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../.env"

echo "Installing Dokploy on $(hostname) (${TARGET_IP:-unknown IP})..."

if [ -n "${DOKPLOY_VERSION:-}" ]; then
  echo "Pinning Dokploy version ${DOKPLOY_VERSION}"
  curl -sSL https://dokploy.com/install.sh | ADVERTISE_ADDR="${TARGET_IP}" sh -s -- --version "${DOKPLOY_VERSION}"
else
  curl -sSL https://dokploy.com/install.sh | ADVERTISE_ADDR="${TARGET_IP}" sh
fi

cat <<EOF

Dokploy install finished.

Next steps (manual, one-time, in the browser):
  1. Open http://${TARGET_IP}:3000 and create the admin account.
     -> Use a password manager entry, this is your infra root account.
  2. Under Settings > Server, confirm the detected IP matches ${TARGET_IP}.
  3. If this run is for step 3 (real server) and DNS/domain is ready,
     go straight to docs/app-notes-*.md "Domain & SSL" sections.
  4. Otherwise (step 2 test run), skip domains for now and deploy apps
     using the templates/ compose files — see MIGRATION-RUNBOOK.md.

Record the admin URL + account in your password manager now, not later.
EOF

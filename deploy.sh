#!/bin/bash
# Master deploy script for vps-bootstrap
# Usage: bash deploy.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/vps-bootstrap"
mkdir -p "$LOG_DIR"

if [[ ! -f "$SCRIPT_DIR/config.env" ]]; then
  echo "ERROR: config.env not found. Run: cp config.env.example config.env && nano config.env"
  exit 1
fi

# Validate config
set -a
source "$SCRIPT_DIR/config.env"
set +a
: "${DOMAIN:?DOMAIN must be set in config.env}"
: "${ADMIN_EMAIL:?ADMIN_EMAIL must be set in config.env}"

# Init credentials file
CRED_FILE="/root/vps-bootstrap-credentials.txt"
if [[ ! -f "$CRED_FILE" ]]; then
  cat > "$CRED_FILE" <<EOF
============================================================
vps-bootstrap credentials for $DOMAIN
Generated: $(date)
============================================================
EOF
  chmod 600 "$CRED_FILE"
fi

# Order of scripts
SCRIPTS=(
  "00-bootstrap.sh"
  "01-hardening.sh"
  "02-openlitespeed.sh"
  "03-mariadb-redis.sh"
  "04-create-vhost.sh"
  "05-install-wordpress.sh"
)

[[ "${SKIP_SSL:-0}" != "1" ]] && SCRIPTS+=("06-ssl.sh")
[[ "${SKIP_BACKUPS:-0}" != "1" && -n "${B2_BUCKET:-}" ]] && SCRIPTS+=("07-backups.sh")
SCRIPTS+=("99-final-check.sh")

for script in "${SCRIPTS[@]}"; do
  echo ""
  echo "============================================"
  echo "[$(date +%H:%M:%S)] Running $script"
  echo "============================================"
  bash "$SCRIPT_DIR/scripts/$script" 2>&1 | tee "$LOG_DIR/${script%.sh}.log"
done

echo ""
echo "============================================"
echo "Deploy completed for $DOMAIN"
echo "============================================"
echo "Credentials: $CRED_FILE"
echo "Logs: $LOG_DIR/"
echo ""
echo "Next steps (manual):"
echo "  1. Copia las credenciales a tu password manager"
echo "  2. shred -u $CRED_FILE"
echo "  3. Ver docs/post-install.md para Cloudflare/DNS"

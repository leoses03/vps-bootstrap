#!/bin/bash
# 07-backups.sh — rclone + cron diario a Backblaze B2
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"

if [[ -z "${B2_BUCKET:-}" || -z "${B2_REMOTE_NAME:-}" ]]; then
  echo "[07] B2_BUCKET or B2_REMOTE_NAME not set. Skipping backups setup."
  exit 0
fi

if ! command -v rclone &>/dev/null; then
  echo "[07] Installing rclone..."
  curl -fsSL https://rclone.org/install.sh | bash
fi

if ! rclone listremotes 2>/dev/null | grep -q "^${B2_REMOTE_NAME}:"; then
  echo "[07] ERROR: rclone remote '${B2_REMOTE_NAME}' not configured."
  echo "[07] Run: rclone config"
  echo "[07] Create a new B2 remote named '${B2_REMOTE_NAME}' with your B2 keyID + applicationKey,"
  echo "[07] then re-run this script."
  exit 1
fi

mkdir -p /root/scripts

BACKUP_SCRIPT="/root/scripts/backup-$DOMAIN.sh"
echo "[07] Creating $BACKUP_SCRIPT..."

cat > "$BACKUP_SCRIPT" <<BACKEOF
#!/bin/bash
set -euo pipefail
DATE=\$(date +%Y%m%d_%H%M%S)
WEB_ROOT="/var/www/$DOMAIN/public_html"
BACKUP_DIR="/var/backups/$DOMAIN"
B2_REMOTE="${B2_REMOTE_NAME}:${B2_BUCKET}"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-14}

mkdir -p "\$BACKUP_DIR"
cd "\$BACKUP_DIR"

echo "[\$(date)] Dumping database..."
wp db export "db-\$DATE.sql" --allow-root --path="\$WEB_ROOT"
gzip -f "db-\$DATE.sql"

echo "[\$(date)] Archiving files..."
tar --exclude='wp-content/cache' \\
    --exclude='wp-content/litespeed' \\
    --exclude='wp-content/uploads/cache' \\
    --exclude='wp-content/upgrade' \\
    -czf "wp-content-\$DATE.tar.gz" \\
    -C "\$WEB_ROOT" wp-content wp-config.php

echo "[\$(date)] Uploading to B2..."
rclone copy "db-\$DATE.sql.gz" "\$B2_REMOTE/daily/"
rclone copy "wp-content-\$DATE.tar.gz" "\$B2_REMOTE/daily/"

echo "[\$(date)] Cleaning old backups..."
find "\$BACKUP_DIR" -type f -mtime +7 -delete
rclone delete --min-age "\${RETENTION_DAYS}d" "\$B2_REMOTE/daily/"

echo "[\$(date)] Backup OK"
BACKEOF

chmod +x "$BACKUP_SCRIPT"

echo "[07] Setting up cron (3 AM ${TIMEZONE_FOR_CRON:-UTC})..."
CRON_FILE="/etc/cron.d/backup-$DOMAIN"
echo "CRON_TZ=${TIMEZONE_FOR_CRON:-UTC}" > "$CRON_FILE"
echo "0 3 * * * root $BACKUP_SCRIPT >> /var/log/backup-$DOMAIN.log 2>&1" >> "$CRON_FILE"
echo "" >> "$CRON_FILE"

systemctl restart crond

# Backup de prueba
echo "[07] Running initial backup test..."
bash "$BACKUP_SCRIPT"

echo "[07] Done. Backups daily at 3 AM ${TIMEZONE_FOR_CRON:-UTC}."

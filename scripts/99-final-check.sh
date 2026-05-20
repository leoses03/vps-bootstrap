#!/bin/bash
# 99-final-check.sh — verifica que todo el stack esté arriba
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"

echo ""
echo "============================================"
echo "Final check for $DOMAIN"
echo "============================================"

echo ""
echo "=== Services ==="
for svc in lsws mariadb redis fail2ban crond firewalld; do
  STATE=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
  printf "%-15s %s\n" "$svc:" "$STATE"
done

echo ""
echo "=== Ports listening ==="
ss -tlnp 2>/dev/null | awk 'NR>1 {print $4}' | sort -u | grep -E ':(22|80|443|7080)\b' || echo "(none expected)"

echo ""
echo "=== Firewall ==="
firewall-cmd --list-ports 2>/dev/null
firewall-cmd --list-services 2>/dev/null

echo ""
echo "=== Redis ping ==="
redis-cli ping 2>/dev/null || echo "redis unreachable"

echo ""
echo "=== HTTP test (Host: $DOMAIN) ==="
curl -sI -H "Host: $DOMAIN" http://127.0.0.1 --max-time 5 | head -1 || echo "HTTP not reachable"

if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
  echo ""
  echo "=== HTTPS cert ==="
  openssl x509 -enddate -noout -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" 2>/dev/null
  echo ""
  echo "=== HTTPS test ==="
  curl -sI -H "Host: $DOMAIN" -k https://127.0.0.1 --max-time 5 | head -1 || echo "HTTPS not reachable"
fi

echo ""
echo "=== WordPress ==="
DOCROOT="/var/www/$DOMAIN/public_html"
if [[ -f "$DOCROOT/wp-config.php" ]]; then
  cd "$DOCROOT"
  echo "WP version: $(wp core version --allow-root 2>/dev/null)"
  echo "Site URL: $(wp option get siteurl --allow-root 2>/dev/null)"
  echo "Active plugins: $(wp plugin list --status=active --field=name --allow-root 2>/dev/null | tr '\n' ',' | sed 's/,$//')"
fi

echo ""
echo "=== Disk / RAM ==="
df -h / | tail -1
free -h | head -2

echo ""
echo "=== Backups (last 2 in B2) ==="
if [[ -n "${B2_REMOTE_NAME:-}" && -n "${B2_BUCKET:-}" ]]; then
  rclone ls "${B2_REMOTE_NAME}:${B2_BUCKET}/daily/" 2>/dev/null | sort | tail -2 || echo "B2 not configured or no backups yet"
else
  echo "Backups disabled in config.env"
fi

echo ""
echo "=== Credentials ==="
ls -la /root/vps-bootstrap-credentials.txt 2>/dev/null && echo "→ cat /root/vps-bootstrap-credentials.txt to view"

echo ""
echo "============================================"
echo "All checks done."
echo "============================================"

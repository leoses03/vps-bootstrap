#!/bin/bash
# 06-ssl.sh — Let's Encrypt + HTTPS listener + auto-renew hook
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"
DOCROOT="/var/www/$DOMAIN/public_html"

if ! command -v certbot &>/dev/null; then
  echo "[06] Installing certbot..."
  dnf install -y -q certbot
fi

# Verifica que DNS resuelva al VPS antes de pedir cert (sino Let's Encrypt rechaza)
VPS_IP=$(curl -s -4 ifconfig.me)
DOMAIN_IP=$(dig +short A "$DOMAIN" | tail -1)
if [[ -z "$DOMAIN_IP" ]] || [[ "$DOMAIN_IP" != "$VPS_IP" ]]; then
  echo "[06] WARNING: DNS for $DOMAIN does not resolve to this VPS ($VPS_IP). Currently resolves to: ${DOMAIN_IP:-nothing}"
  echo "[06] Skipping SSL. Once DNS propagates, run: bash scripts/06-ssl.sh"
  exit 0
fi

echo "[06] Issuing Let's Encrypt cert for $DOMAIN and www.$DOMAIN..."
certbot certonly --webroot \
  -w "$DOCROOT" \
  -d "$DOMAIN" \
  -d "www.$DOMAIN" \
  --email "$ADMIN_EMAIL" \
  --agree-tos \
  --no-eff-email \
  --non-interactive \
  --keep-until-expiring

echo "[06] Setting up renewal hook (auto-reload OLS)..."
mkdir -p /etc/letsencrypt/renewal-hooks/deploy
echo '#!/bin/bash' > /etc/letsencrypt/renewal-hooks/deploy/reload-lsws.sh
echo '/usr/local/lsws/bin/lswsctrl restart' >> /etc/letsencrypt/renewal-hooks/deploy/reload-lsws.sh
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-lsws.sh

HTTPD_CONF="/usr/local/lsws/conf/httpd_config.conf"

if ! grep -q "^listener HTTPS {" "$HTTPD_CONF"; then
  echo "[06] Adding HTTPS listener to OLS..."
  cat >> "$HTTPD_CONF" <<EOF

listener HTTPS {
  address                 *:443
  secure                  1
  keyFile                 /etc/letsencrypt/live/$DOMAIN/privkey.pem
  certFile                /etc/letsencrypt/live/$DOMAIN/fullchain.pem
  certChain               1
  sslProtocol             24
  map                     $DOMAIN $DOMAIN, www.$DOMAIN
}
EOF
fi

systemctl restart lsws
sleep 2

# Actualizar WP a HTTPS
cd "$DOCROOT"
wp option update siteurl "https://$DOMAIN" --allow-root
wp option update home "https://$DOMAIN" --allow-root

echo "[06] SSL ready. Cert path: /etc/letsencrypt/live/$DOMAIN/"
echo "[06] Done."

#!/bin/bash
# 05-install-wordpress.sh — wp-cli + WordPress + LSCache + Redis Object Cache
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"
PHP_VER="${PHP_VERSION:-82}"

DOCROOT="/var/www/$DOMAIN/public_html"

# Symlink php para wp-cli
if [[ ! -L /usr/bin/php ]]; then
  ln -sf /usr/local/lsws/lsphp${PHP_VER}/bin/php /usr/bin/php
fi

# Install wp-cli si no está
if ! command -v wp &>/dev/null; then
  echo "[05] Installing wp-cli..."
  curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp
fi

# Generar credenciales WP DB
SAFE_DOMAIN=$(echo "$DOMAIN" | tr '.-' '__')
WP_DB_NAME="${SAFE_DOMAIN}_wp"
WP_DB_USER=$(echo "$DOMAIN" | cut -d. -f1 | tr -cd 'a-z0-9' | head -c 16)
WP_DB_PASS=$(openssl rand -base64 24 | tr -d '=/+\\')
WP_ADMIN_PASS=$(openssl rand -base64 18 | tr -d '=/+\\')
WP_ADMIN_USER="${WP_ADMIN_USER:-siteadmin}"

# Crear DB + user (usa /root/.my.cnf para root login automático)
echo "[05] Creating WordPress database $WP_DB_NAME..."
mysql <<EOF
CREATE DATABASE IF NOT EXISTS $WP_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
ALTER USER '$WP_DB_USER'@'localhost' IDENTIFIED BY '$WP_DB_PASS';
GRANT ALL PRIVILEGES ON $WP_DB_NAME.* TO '$WP_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

cd "$DOCROOT"
rm -f index.html

echo "[05] Downloading WordPress (locale ${WP_LOCALE:-en_US})..."
wp core download --locale="${WP_LOCALE:-en_US}" --allow-root --force

echo "[05] Creating wp-config.php..."
wp config create \
  --dbname="$WP_DB_NAME" \
  --dbuser="$WP_DB_USER" \
  --dbpass="$WP_DB_PASS" \
  --dbhost=localhost \
  --dbcharset=utf8mb4 \
  --dbcollate=utf8mb4_unicode_ci \
  --allow-root \
  --force

# Constantes para Redis
wp config set WP_REDIS_PATH '/var/run/redis/redis.sock' --type=constant --allow-root
wp config set WP_REDIS_SCHEME 'unix' --type=constant --allow-root
wp config set WP_REDIS_DATABASE 0 --type=constant --raw --allow-root
wp config set WP_CACHE true --type=constant --raw --allow-root

echo "[05] Installing WordPress core..."
wp core install \
  --url="http://$DOMAIN" \
  --title="${WP_SITE_TITLE:-$DOMAIN}" \
  --admin_user="$WP_ADMIN_USER" \
  --admin_password="$WP_ADMIN_PASS" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email \
  --allow-root

echo "[05] Setting permalinks..."
wp option update permalink_structure '/%postname%/' --allow-root
wp rewrite flush --hard --allow-root

echo "[05] Adding WordPress rewrite rules to .htaccess (OLS doesn't auto-write them)..."
if ! grep -q "# BEGIN WordPress" "$DOCROOT/.htaccess" 2>/dev/null; then
  cat >> "$DOCROOT/.htaccess" <<HTEOF

# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php\$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTEOF
fi

echo "[05] Installing Redis Object Cache + LiteSpeed Cache plugins..."
wp plugin install redis-cache --activate --allow-root
wp redis enable --allow-root
wp plugin install litespeed-cache --activate --allow-root

# LSCache defaults
wp litespeed-option set cache true --allow-root
wp litespeed-option set cache-priv true --allow-root
wp litespeed-option set cache-rest true --allow-root
wp litespeed-option set cache-browser true --allow-root

chown -R nobody:nobody "$DOCROOT"

cat >> /root/vps-bootstrap-credentials.txt <<CREDEOF

[WordPress admin]
URL: http://$DOMAIN/wp-admin
User: $WP_ADMIN_USER
Password: $WP_ADMIN_PASS
Email: $ADMIN_EMAIL

[WordPress DB]
Host: localhost
DB Name: $WP_DB_NAME
DB User: $WP_DB_USER
DB Password: $WP_DB_PASS
CREDEOF

systemctl restart lsws

echo "[05] Done."

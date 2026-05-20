#!/bin/bash
# 02-openlitespeed.sh — OpenLiteSpeed + PHP 8.2 + tuning
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"
PHP_VER="${PHP_VERSION:-82}"

echo "[02] Adding LiteSpeed repo..."
if ! rpm -q litespeed-repo &>/dev/null; then
  rpm -Uvh https://repo.litespeed.sh/centos/litespeed-repo-1.2-1.el9.noarch.rpm
fi

echo "[02] Installing OpenLiteSpeed..."
dnf install -y -q openlitespeed

echo "[02] Installing PHP $PHP_VER + WP extensions..."
dnf install -y -q \
  lsphp${PHP_VER} \
  lsphp${PHP_VER}-common \
  lsphp${PHP_VER}-mysqlnd \
  lsphp${PHP_VER}-gd \
  lsphp${PHP_VER}-mbstring \
  lsphp${PHP_VER}-xml \
  lsphp${PHP_VER}-bcmath \
  lsphp${PHP_VER}-zip \
  lsphp${PHP_VER}-opcache \
  lsphp${PHP_VER}-intl \
  lsphp${PHP_VER}-soap \
  lsphp${PHP_VER}-sodium \
  lsphp${PHP_VER}-pecl-redis \
  lsphp${PHP_VER}-pecl-imagick \
  lsphp${PHP_VER}-process

echo "[02] Tuning php.ini..."
PHP_INI="/usr/local/lsws/lsphp${PHP_VER}/etc/php.ini"
sed -i "s/^memory_limit = .*/memory_limit = ${PHP_MEMORY_LIMIT:-512M}/" "$PHP_INI"
sed -i "s/^upload_max_filesize = .*/upload_max_filesize = ${PHP_UPLOAD_MAX:-128M}/" "$PHP_INI"
sed -i "s/^post_max_size = .*/post_max_size = ${PHP_POST_MAX:-128M}/" "$PHP_INI"
sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "$PHP_INI"
sed -i 's/^max_input_time = .*/max_input_time = 300/' "$PHP_INI"

echo "[02] Linking php -> lsphp${PHP_VER}..."
ln -sf /usr/local/lsws/lsphp${PHP_VER}/bin/php /usr/bin/php

echo "[02] Setting WebAdmin password..."
ADMIN_PASS=$(openssl rand -base64 18)
{
  echo "admin"
  echo "$ADMIN_PASS"
  echo "$ADMIN_PASS"
} | /usr/local/lsws/admin/misc/admpass.sh >/dev/null 2>&1 || true

cat >> /root/vps-bootstrap-credentials.txt <<EOF

[OpenLiteSpeed WebAdmin Console]
URL: https://VPS_IP:7080 (only via SSH tunnel: ssh -L 7080:127.0.0.1:7080 root@VPS_IP)
User: admin
Password: $ADMIN_PASS
EOF

echo "[02] Enabling OpenLiteSpeed..."
systemctl enable --now lsws

echo "[02] Done."

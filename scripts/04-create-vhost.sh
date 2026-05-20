#!/bin/bash
# 04-create-vhost.sh — crea docroot, vhost config y listener HTTP
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"
PHP_VER="${PHP_VERSION:-82}"

DOCROOT="/var/www/$DOMAIN/public_html"
LOGS_DIR="/var/www/$DOMAIN/logs"
VHOST_CONF_DIR="/usr/local/lsws/conf/vhosts/$DOMAIN"

echo "[04] Creating docroot at $DOCROOT..."
mkdir -p "$DOCROOT" "$LOGS_DIR"
echo "<h1>$DOMAIN bootstrap OK</h1>" > "$DOCROOT/index.html"
chown -R nobody:nobody "/var/www/$DOMAIN"

echo "[04] Writing vhost config..."
mkdir -p "$VHOST_CONF_DIR"
cat > "$VHOST_CONF_DIR/vhconf.conf" <<EOF
docRoot                   \$VH_ROOT/public_html
vhDomain                  $DOMAIN
vhAliases                 www.$DOMAIN
adminEmails               $ADMIN_EMAIL
enableGzip                1
enableBr                  1

errorlog \$VH_ROOT/logs/error.log {
  useServer               0
  logLevel                ERROR
  rollingSize             10M
}

accesslog \$VH_ROOT/logs/access.log {
  useServer               0
  rollingSize             10M
  keepDays                30
  compressArchive         1
}

index  {
  useServer               0
  indexFiles              index.php, index.html, index.htm
  autoIndex               0
}

scripthandler  {
  add                     lsapi:lsphp${PHP_VER} php
}

extprocessor lsphp${PHP_VER} {
  type                    lsapi
  address                 uds://tmp/lshttpd/lsphp${PHP_VER}.sock
  maxConns                10
  env                     PHP_LSAPI_CHILDREN=10
  initTimeout             60
  retryTimeout            0
  persistConn             1
  pcKeepAliveTimeout      1
  respBuffer              0
  autoStart               2
  path                    /usr/local/lsws/lsphp${PHP_VER}/bin/lsphp
  backlog                 100
  instances               1
  memSoftLimit            2047M
  memHardLimit            2047M
  procSoftLimit           400
  procHardLimit           500
}

rewrite  {
  enable                  1
  autoLoadHtaccess        1
  logLevel                0
}

context / {
  allowBrowse             1
  rewrite  {
    inherit               1
  }
}
EOF

chown -R lsadm:lsadm "$VHOST_CONF_DIR" 2>/dev/null || true

echo "[04] Adding vhost + HTTP listener to httpd_config.conf..."
HTTPD_CONF="/usr/local/lsws/conf/httpd_config.conf"
cp "$HTTPD_CONF" "${HTTPD_CONF}.bak-bootstrap"

# Quitar el sitio Default y Example demo
sed -i '/^listener Default {/,/^}/d' "$HTTPD_CONF"
sed -i '/^virtualhost Example {/,/^}/d' "$HTTPD_CONF"

# Agregar nuestro vhost y listener si no existen
if ! grep -q "^virtualhost $DOMAIN {" "$HTTPD_CONF"; then
  cat >> "$HTTPD_CONF" <<EOF

virtualhost $DOMAIN {
  vhRoot                  /var/www/$DOMAIN/
  configFile              \$SERVER_ROOT/conf/vhosts/\$VH_NAME/vhconf.conf
  allowSymbolLink         1
  enableScript            1
  restrained              1
  setUIDMode              0
}
EOF
fi

if ! grep -q "^listener HTTP {" "$HTTPD_CONF"; then
  cat >> "$HTTPD_CONF" <<EOF

listener HTTP {
  address                 *:80
  secure                  0
  map                     $DOMAIN $DOMAIN, www.$DOMAIN
}
EOF
fi

systemctl restart lsws
echo "[04] Done."

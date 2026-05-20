#!/bin/bash
# 03-mariadb-redis.sh — MariaDB + Redis (Unix socket)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"
DB_VER="${MARIADB_VERSION:-11.4}"

echo "[03] Adding MariaDB repo (v$DB_VER LTS)..."
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-$DB_VER" --skip-maxscale --skip-tools 2>/dev/null

echo "[03] Installing MariaDB + Redis..."
dnf install -y -q MariaDB-server MariaDB-client redis

echo "[03] Starting services..."
systemctl enable --now mariadb redis

echo "[03] Securing MariaDB..."
MYSQL_ROOT_PASS=$(openssl rand -base64 24)

# Hace lo equivalente a mariadb-secure-installation pero no-interactivo
mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
DELETE FROM mysql.global_priv WHERE User='';
DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# Guardar root pass para uso futuro sin tener que escribirla
cat > /root/.my.cnf <<EOF
[client]
user=root
password=$MYSQL_ROOT_PASS
EOF
chmod 600 /root/.my.cnf

cat >> /root/vps-bootstrap-credentials.txt <<EOF

[MariaDB root]
User: root
Password: $MYSQL_ROOT_PASS
Note: also saved in /root/.my.cnf for CLI auto-login (mysql sin -p)
EOF

echo "[03] Configuring Redis with Unix socket..."
sed -i 's|^# *unixsocket /.*|unixsocket /var/run/redis/redis.sock|' /etc/redis/redis.conf
sed -i 's|^# *unixsocketperm .*|unixsocketperm 770|' /etc/redis/redis.conf

mkdir -p /var/run/redis
chown redis:redis /var/run/redis
chmod 755 /var/run/redis

echo "[03] Adding nobody to redis group..."
usermod -a -G redis nobody

systemctl restart redis

echo "[03] Done."

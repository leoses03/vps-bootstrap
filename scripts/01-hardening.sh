#!/bin/bash
# 01-hardening.sh — firewall + fail2ban
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"

echo "[01] Enabling firewalld..."
systemctl enable --now firewalld

echo "[01] Configuring firewall (SSH + HTTP + HTTPS + QUIC)..."
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=443/udp  # HTTP/3
firewall-cmd --permanent --remove-service=cockpit 2>/dev/null || true
firewall-cmd --reload
systemctl disable --now cockpit.socket 2>/dev/null || true

echo "[01] Configuring fail2ban..."
echo '[sshd]' > /etc/fail2ban/jail.local
echo 'enabled = true' >> /etc/fail2ban/jail.local
echo 'bantime = 3600' >> /etc/fail2ban/jail.local
echo 'maxretry = 5' >> /etc/fail2ban/jail.local

systemctl enable --now fail2ban
echo "[01] Done."

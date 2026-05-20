#!/bin/bash
# 00-bootstrap.sh — update, utilities, hostname, swap
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../config.env"

echo "[00] dnf update..."
dnf update -y -q

echo "[00] EPEL repo..."
dnf install -y -q epel-release
dnf makecache -q

echo "[00] Utilities..."
dnf install -y -q \
  wget tar unzip curl \
  vim nano htop iotop \
  bind-utils \
  policycoreutils-python-utils \
  fail2ban \
  tmux

echo "[00] Hostname: $DOMAIN"
hostnamectl set-hostname "$DOMAIN"

# Swap
SWAP_SIZE_GB="${SWAP_GB:-2}"
if [[ ! -f /swapfile ]]; then
  echo "[00] Creating ${SWAP_SIZE_GB} GB swap..."
  dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE_GB * 1024)) status=none
  chmod 600 /swapfile
  mkswap /swapfile -q
  swapon /swapfile
  if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
fi

echo "[00] Done."

#!/usr/bin/env bash
set -euo pipefail

############################################
# Rocky Linux 9 Base System Preparation
# Foundation for Asterisk + VICIdial
############################################

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/vicidial-installer.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================="
echo "[$SCRIPT_NAME] Starting Rocky 9 base preparation"
echo "================================================="

### --- SAFETY CHECKS ---
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] This script must be run as root"
  exit 1
fi

if ! grep -qi rocky /etc/os-release; then
  echo "[ERROR] This installer supports Rocky Linux 9 only"
  cat /etc/os-release
  exit 1
fi

### --- TIMEZONE & LOCALE ---
echo "[INFO] Setting timezone and locale"
timedatectl set-timezone UTC
localectl set-locale LANG=en_US.UTF-8

### --- SYSTEM UPDATE ---
echo "[INFO] Updating system packages"
dnf -y update

### --- REPOSITORIES ---
echo "[INFO] Enabling CRB, EPEL repositories"
dnf -y install epel-release
dnf config-manager --set-enabled crb

### --- CORE UTILITIES ---
echo "[INFO] Installing core system utilities"
dnf -y install \
  wget curl git rsync vim nano \
  net-tools bind-utils \
  chrony unzip tar \
  policycoreutils-python-utils

### --- TIME SYNC ---
echo "[INFO] Enabling NTP (chrony)"
systemctl enable --now chronyd

### --- SELINUX (PERMISSIVE, NOT DISABLED) ---
echo "[INFO] Setting SELinux to permissive"
setenforce 0 || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

### --- FIREWALL (TEMPORARILY DISABLED) ---
echo "[INFO] Disabling firewalld (will be re-enabled later)"
systemctl stop firewalld || true
systemctl disable firewalld || true

### --- SWAP CHECK ---
if ! swapon --show | grep -q '^'; then
  echo "[WARN] No swap detected (recommended for Asterisk stability)"
else
  echo "[INFO] Swap detected"
fi

### --- KERNEL & LIMIT TUNING ---
echo "[INFO] Applying kernel tuning"

cat >/etc/sysctl.d/99-vicidial.conf <<EOF
# VICIdial / Asterisk tuning
fs.file-max = 1000000
net.core.somaxconn = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
EOF

sysctl --system

### --- LIMITS ---
echo "[INFO] Setting system limits"

cat >/etc/security/limits.d/99-vicidial.conf <<EOF
asterisk soft nofile 100000
asterisk hard nofile 100000
root     soft nofile 100000
root     hard nofile 100000
EOF

### --- DISABLE UNNEEDED SERVICES ---
echo "[INFO] Disabling unused services"
systemctl disable --now postfix || true

### --- DIRECTORIES ---
echo "[INFO] Creating base directories"
mkdir -p /usr/src /opt/vicidial /var/log/astguiclient

### --- FINAL CHECKPOINT ---
echo "================================================="
echo "[SUCCESS] Rocky 9 base system prepared"
echo "================================================="

echo "[INFO] Reboot recommended before proceeding to Asterisk build"

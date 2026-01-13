#!/usr/bin/env bash
set -euo pipefail

############################################
# Asterisk 18 Build Dependencies
# Rocky Linux 9
############################################

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/vicidial-installer.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "================================================="
echo "[$SCRIPT_NAME] Installing Asterisk build deps"
echo "================================================="

### --- SAFETY ---
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Must be run as root"
  exit 1
fi

### --- ENABLE DEV REPOS ---
echo "[INFO] Enabling required repositories"
dnf -y groupinstall "Development Tools"
dnf -y install dnf-plugins-core

### --- CORE BUILD TOOLS ---
echo "[INFO] Installing core build packages"
dnf -y install \
  gcc gcc-c++ make cmake autoconf automake libtool \
  patch diffutils \
  wget curl git subversion \
  ncurses-devel readline-devel \
  libuuid-devel jansson-devel \
  libxml2-devel sqlite-devel \
  openssl-devel \
  libedit-devel \
  unixODBC unixODBC-devel \
  speex speex-devel \
  libogg libogg-devel \
  libvorbis libvorbis-devel \
  opus opus-devel \
  pcre pcre-devel \
  perl \
  python3

### --- MEDIA / CODECS ---
echo "[INFO] Installing media & codec libraries"
dnf -y install \
  sox sox-devel \
  lame lame-devel || true

### --- DATABASE CLIENT LIBS ---
echo "[INFO] Installing MariaDB client libraries"
dnf -y install \
  mariadb mariadb-connector-c mariadb-connector-c-devel

### --- CURL / HTTP ---
dnf -y install \
  libcurl libcurl-devel

### --- UUID / JSON ---
dnf -y install \
  util-linux \
  jq

### --- Asterisk Runtime Utilities ---
echo "[INFO] Installing runtime utilities"
dnf -y install \
  iproute \
  tcpdump \
  nmap-ncat \
  rsyslog \
  cronie \
  logrotate

### --- REMOVE CONFLICTING PACKAGES ---
echo "[INFO] Removing conflicting packages (if any)"
dnf -y remove \
  asterisk \
  dahdi-linux \
  dahdi-tools || true

### --- FINAL CHECK ---
echo "================================================="
echo "[SUCCESS] Asterisk build dependencies installed"
echo "================================================="

echo "[INFO] Next step: 02-download-asterisk.sh"

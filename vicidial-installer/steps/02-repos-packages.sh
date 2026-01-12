#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 02: Repositories & Base Packages"
echo "=================================================="

# ---------------------------------------------------
# Sanity: must be run via installer
# ---------------------------------------------------
if [[ -z "${LOG_FILE:-}" ]]; then
  echo "[FATAL] LOG_FILE not set — run via install.sh"
  exit 1
fi

# ---------------------------------------------------
# Enable repositories (IDEMPOTENT)
# ---------------------------------------------------
echo "[+] Enabling EPEL & Remi repositories"

dnf install -y epel-release
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
dnf install -y dnf-utils

dnf config-manager --set-enabled powertools || true

# Enable PHP 7.4 from Remi
dnf module reset php -y
dnf module enable php:remi-7.4 -y

# ---------------------------------------------------
# Development tools (Asterisk / Perl build)
# ---------------------------------------------------
echo "[+] Installing Development Tools"

dnf groupinstall -y "Development Tools"

# ---------------------------------------------------
# Core system utilities
# ---------------------------------------------------
echo "[+] Installing core system utilities"

dnf install -y \
  tar \
  curl \
  wget \
  unzip \
  screen \
  which \
  net-tools \
  htop \
  iftop \
  nc \
  patch \
  sox \
  sendmail \
  mutt \
  certbot \
  mod_ssl

# ---------------------------------------------------
# Apache + PHP (Remi 7.4)
# ---------------------------------------------------
echo "[+] Installing Apache & PHP"

dnf install -y \
  httpd \
  php \
  php-cli \
  php-common \
  php-mysqlnd \
  php-gd \
  php-mbstring \
  php-xml \
  php-json \
  php-opcache \
  php-ldap \
  php-imap \
  php-zip \
  php-curl \
  php-pear

# ---------------------------------------------------
# Asterisk build dependencies
# ---------------------------------------------------
echo "[+] Installing Asterisk dependencies"

dnf install -y \
  openssl-devel \
  ncurses-devel \
  newt-devel \
  libxml2-devel \
  libuuid-devel \
  libedit-devel \
  jansson-devel \
  sqlite-devel \
  libpcap \
  libpcap-devel \
  ImageMagick \
  lame-devel

# ---------------------------------------------------
# Database / SVN / Misc
# ---------------------------------------------------
echo "[+] Installing database & version control tools"

dnf install -y \
  mariadb-devel \
  subversion \
  perl-File-Which

# ---------------------------------------------------
# Security tooling (used later)
# ---------------------------------------------------
dnf install -y fail2ban || true

echo "[OK] Repositories & packages installed successfully"
echo "=================================================="

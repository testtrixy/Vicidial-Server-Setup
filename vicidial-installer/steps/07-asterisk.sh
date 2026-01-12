#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 07: Asterisk Build & Install"
echo "=================================================="

ASTERISK_SRC="/usr/src/asterisk-13.29.2"

cd "$ASTERISK_SRC"

# ---------------------------------------------------
# 1. Configure Asterisk
# ---------------------------------------------------
echo "[+] Configuring Asterisk"

./configure \
  --libdir=/usr/lib64 \
  --with-pjproject-bundled \
  --with-jansson-bundled

# ---------------------------------------------------
# 2. Build menuselect explicitly (CRITICAL)
# ---------------------------------------------------
echo "[+] Building menuselect"
make menuselect

if [ ! -x menuselect/menuselect ]; then
  echo "[FATAL] menuselect binary not found after build"
  exit 1
fi

# ---------------------------------------------------
# 3. Auto-select required modules for VICIdial
# ---------------------------------------------------
echo "[+] Selecting Asterisk modules"

menuselect/menuselect \
  --enable app_meetme \
  --enable res_http_websocket \
  --enable res_srtp \
  menuselect.makeopts

# ---------------------------------------------------
# 4. Build and install Asterisk
# ---------------------------------------------------
echo "[+] Building Asterisk"
make -j$(nproc)

echo "[+] Installing Asterisk"
make install
make samples
make config

# ---------------------------------------------------
# 5. Verify installation
# ---------------------------------------------------
if ! command -v asterisk >/dev/null 2>&1; then
  echo "[FATAL] Asterisk binary not found after install"
  exit 1
fi



# ---------------------------------------------------
# Ensure asterisk user exists (Rocky-safe)
# ---------------------------------------------------

if ! id asterisk &>/dev/null; then
  echo "[+] Creating asterisk system user"
  useradd -r -d /var/lib/asterisk -s /sbin/nologin asterisk
fi


echo "[OK] Asterisk installed successfully"
echo "=================================================="


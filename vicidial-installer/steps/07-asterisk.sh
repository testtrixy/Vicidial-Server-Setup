#!/bin/bash
set -euo pipefail


ASTERISK_VER="13.29.2"
ASTERISK_TARBALL="asterisk-${ASTERISK_VER}-vici.tar.gz"
ASTERISK_URL="http://download.vicidial.com/required-apps/${ASTERISK_TARBALL}"
SRC_DIR="/usr/src"
SRC="${SRC_DIR}/asterisk-${ASTERISK_VER}"

echo "=================================================="
echo " STEP 07: Asterisk Build & Install"
echo "=================================================="

# ---------------------------------------------------
# Sanity checks
# ---------------------------------------------------
command -v gcc >/dev/null || { echo "[FATAL] gcc not installed"; exit 1; }
command -v make >/dev/null || { echo "[FATAL] make not installed"; exit 1; }
command -v tar >/dev/null || { echo "[FATAL] tar not installed"; exit 1; }

cd "$SRC_DIR"

# ---------------------------------------------------
# Download tarball if missing
# ---------------------------------------------------
if [ ! -f "$ASTERISK_TARBALL" ]; then
  echo "[+] Downloading Asterisk source tarball"
  curl -fL "$ASTERISK_URL" -o "$ASTERISK_TARBALL" \
    || { echo "[FATAL] Failed to download $ASTERISK_TARBALL"; exit 1; }
else
  echo "[OK] Asterisk tarball already present"
fi

# ---------------------------------------------------
# Extract source if not already extracted
# ---------------------------------------------------
if [ ! -d "$SRC" ]; then
  echo "[+] Extracting Asterisk source"
  tar xzf "$ASTERISK_TARBALL"
else
  echo "[OK] Asterisk source already extracted"
fi

cd "$SRC"

# ---------------------------------------------------
# Fetch MP3 source (REQUIRED for format_mp3)
# ---------------------------------------------------
if [ ! -d contrib/mp3 ]; then
  echo "[+] Fetching MP3 source (required for format_mp3)"
  contrib/scripts/get_mp3_source.sh
fi

# ---------------------------------------------------
# Configure Asterisk
# ---------------------------------------------------
echo "[+] Configuring Asterisk"

./configure \
  --libdir=/usr/lib64 \
  --with-pjproject-bundled \
  --with-jansson-bundled

# ---------------------------------------------------
# Build menuselect (NON-INTERACTIVE)
# ---------------------------------------------------
echo "[+] Building menuselect"
make menuselect

[ -x menuselect/menuselect ] || {
  echo "[FATAL] menuselect binary not built"
  exit 1
}

# ---------------------------------------------------
# Enable VICIdial-required modules
# ---------------------------------------------------
echo "[+] Enabling VICIdial modules"
echo "[+] Selecting required Asterisk modules (VICIdial safe)"

menuselect/menuselect \
  --enable app_meetme \
  --enable res_http_websocket \
  --enable res_srtp \
  --disable format_mp3 \
  menuselect.makeopts


# ---------------------------------------------------
# Build & install Asterisk
# ---------------------------------------------------
echo "[+] Building Asterisk"
make -j"$(nproc)"

echo "[+] Installing Asterisk"
make install
make config

# ---------------------------------------------------
# Create asterisk user if missing
# ---------------------------------------------------
if ! id asterisk &>/dev/null; then
  echo "[+] Creating asterisk system user"
  useradd -r -d /var/lib/asterisk -s /sbin/nologin asterisk
fi

# ---------------------------------------------------
# Enable and start Asterisk
# ---------------------------------------------------
echo "[+] Enabling and starting Asterisk service"
systemctl enable asterisk
systemctl restart asterisk
sleep 5

if ! systemctl is-active --quiet asterisk; then
  echo "[FATAL] Asterisk failed to start"
  journalctl -u asterisk --no-pager | tail -n 50
  exit 1
fi

echo "[OK] Asterisk installed and running"
echo "=================================================="

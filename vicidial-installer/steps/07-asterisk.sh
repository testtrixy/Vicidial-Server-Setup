#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 07: Asterisk Build & Install"
echo "=================================================="

ASTERISK_VER="13.29.2"
ASTERISK_TARBALL="asterisk-${ASTERISK_VER}-vici.tar.gz"
ASTERISK_URL="http://download.vicidial.com/required-apps/${ASTERISK_TARBALL}"
ASTERISK_SRC="/usr/src/asterisk-${ASTERISK_VER}"

# ---------------------------------------------------
# 0. Sanity check – build deps
# ---------------------------------------------------
for bin in gcc make tar; do
  command -v $bin >/dev/null || {
    echo "[FATAL] Missing build dependency: $bin"
    exit 1
  }
done

# ---------------------------------------------------
# 1. Prepare source
# ---------------------------------------------------
mkdir -p /usr/src
cd /usr/src

if [ ! -f "$ASTERISK_TARBALL" ]; then
  echo "[+] Downloading Asterisk ${ASTERISK_VER}"
  wget -q --show-progress "$ASTERISK_URL"
else
  echo "[OK] Asterisk tarball already present"
fi

if [ ! -d "$ASTERISK_SRC" ]; then
  echo "[+] Extracting Asterisk source"
  tar xzf "$ASTERISK_TARBALL"
else
  echo "[OK] Asterisk source already extracted"
fi

cd "$ASTERISK_SRC"

# ---------------------------------------------------
# 2. Configure
# ---------------------------------------------------
echo "[+] Configuring Asterisk"
./configure \
  --libdir=/usr/lib64 \
  --with-pjproject-bundled \
  --with-jansson-bundled

# ---------------------------------------------------
# 3. Build menuselect
# ---------------------------------------------------
echo "[+] Building menuselect"
make menuselect

[ -x menuselect/menuselect ] || {
  echo "[FATAL] menuselect not built"
  exit 1
}

# ---------------------------------------------------
# 4. Force non-interactive menuselect
# ---------------------------------------------------
echo "[+] Forcing non-interactive menuselect"

# Ensure makeopts exists to prevent menu popup
touch menuselect.makeopts

menuselect/menuselect \
  --enable app_meetme \
  --enable res_http_websocket \
  --enable res_srtp \
  menuselect.makeopts
# ---------------------------------------------------
# 5. Build & install
# ---------------------------------------------------
echo "[+] Building Asterisk"
make -j"$(nproc)"

echo "[+] Installing Asterisk"
make install

# Only install samples on fresh system
if [ ! -f /etc/asterisk/asterisk.conf ]; then
  echo "[+] Installing sample configs (first install only)"
  make samples
else
  echo "[INFO] Skipping sample configs (existing system)"
fi

make config

# ---------------------------------------------------
# 6. Create asterisk user safely
# ---------------------------------------------------
if ! id asterisk &>/dev/null; then
  echo "[+] Creating asterisk system user"
  useradd -r -d /var/lib/asterisk -s /sbin/nologin asterisk
fi

# ---------------------------------------------------
# 7. Timing verification (NO DAHDI REQUIRED)
# ---------------------------------------------------
echo "[+] Verifying Asterisk timing"
asterisk -rx "module show like timing" | grep -q timerfd || {
  echo "[FATAL] res_timing_timerfd not loaded"
  exit 1
}

# ---------------------------------------------------
# 8. Final verification
# ---------------------------------------------------
command -v asterisk >/dev/null || {
  echo "[FATAL] Asterisk binary missing"
  exit 1
}

echo "[OK] Asterisk installed and verified"
echo "=================================================="

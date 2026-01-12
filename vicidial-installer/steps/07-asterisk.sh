
#!/bin/bash
set -euo pipefail

exec > >(tee -a "$LOG_FILE") 2>&1
echo "[RUNNING] $0"

ASTERISK_VER="13.29.2"
SRC="/usr/src/asterisk-${ASTERISK_VER}"

echo "=================================================="
echo " STEP 07: Asterisk Build & Install"
echo "=================================================="

cd /usr/src
[ -d "$SRC" ] || tar xzf "asterisk-${ASTERISK_VER}-vici.tar.gz"
cd "$SRC"

# MP3 codec (prevents format_mp3 warnings)
contrib/scripts/get_mp3_source.sh || true

./configure \
  --libdir=/usr/lib64 \
  --with-pjproject-bundled \
  --with-jansson-bundled

make menuselect

menuselect/menuselect \
  --enable app_meetme \
  --enable res_http_websocket \
  --enable res_srtp \
  --enable format_mp3 \
  menuselect.makeopts

make -j"$(nproc)"
make install
make config

# Asterisk user & runtime dirs
id asterisk &>/dev/null || useradd -r -d /var/lib/asterisk -s /sbin/nologin asterisk
mkdir -p /var/run/asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk

echo "[OK] Asterisk installed (Rocky 8 timing model)"

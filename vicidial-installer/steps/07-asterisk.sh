
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

echo "[+] Fetching MP3 source"
contrib/scripts/get_mp3_source.sh || true

echo "[+] Configuring"
./configure --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled

echo "[+] Building menuselect"
make menuselect

touch menuselect.makeopts
menuselect/menuselect \
  --enable app_meetme \
  --enable res_http_websocket \
  --enable res_srtp \
  --enable format_mp3 \
  menuselect.makeopts

echo "[+] Building Asterisk"
make -j"$(nproc)"

echo "[+] Installing"
make install

[ -f /etc/asterisk/asterisk.conf ] || make samples
make config

id asterisk &>/dev/null || useradd -r -d /var/lib/asterisk -s /sbin/nologin asterisk

echo "[OK] Asterisk installed (timing handled at runtime)"

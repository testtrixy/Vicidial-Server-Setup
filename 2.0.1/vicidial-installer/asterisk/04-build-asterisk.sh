#!/usr/bin/env bash
set -euo pipefail

############################################
# Build Asterisk 18 for Vicidial
# Rocky Linux 9
############################################

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/vicidial-installer.log"

exec > >(tee -a "$LOG_FILE") 2>&1

ASTERISK_SRC="/usr/src/asterisk"
MENUSELECT_BIN="menuselect/menuselect"

echo "================================================="
echo "[$SCRIPT_NAME] Building Asterisk for Vicidial"
echo "================================================="

### --- SAFETY ---
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Must be run as root"
  exit 1
fi

if [[ ! -d "$ASTERISK_SRC" ]]; then
  echo "[ERROR] Asterisk source not found: $ASTERISK_SRC"
  exit 1
fi

cd "$ASTERISK_SRC"

### --- CLEAN PREVIOUS BUILDS ---
echo "[INFO] Cleaning previous build artifacts"
make distclean || true

### --- CONFIGURE ---
echo "[INFO] Running ./configure"

./configure \
  --libdir=/usr/lib64 \
  --with-jansson-bundled \
  --with-pjproject-bundled \
  --with-resample \
  --with-speex \
  --with-opus \
  --with-ssl \
  --with-srtp \
  --with-crypto \
  --with-uuid \
  --with-sqlite3 \
  --with-odbc \
  --with-mysqlclient \
  --disable-xmldoc

### --- MENUSELECT DEFAULTS ---
echo "[INFO] Configuring menuselect options"

if [[ ! -x "$MENUSELECT_BIN" ]]; then
  echo "[ERROR] menuselect binary not found"
  exit 1
fi

### --- ENABLE REQUIRED MODULES ---
$MENUSELECT_BIN \
  --enable app_meetme \
  --enable app_confbridge \
  --enable res_odbc \
  --enable res_config_mysql \
  --enable func_odbc \
  --enable cdr_mysql \
  --enable cdr_adaptive_odbc \
  --enable chan_sip \
  --enable chan_pjsip \
  --enable res_http_websocket \
  --enable res_ari \
  --enable res_ari_channels \
  --enable res_ari_events \
  --enable res_ari_bridges \
  menuselect.makeopts

### --- DISABLE MODULES VICIDIAL DOES NOT USE ---
$MENUSELECT_BIN \
  --disable chan_skinny \
  --disable chan_unistim \
  --disable chan_mgcp \
  --disable chan_motif \
  --disable chan_mobile \
  --disable res_pjsip_mwi_body_generator \
  --disable res_snmp \
  --disable res_calendar \
  --disable res_calendar_caldav \
  --disable res_calendar_exchange \
  --disable res_calendar_icalendar \
  --disable app_minivm \
  --disable app_fax \
  --disable app_festival \
  --disable app_sms \
  --disable pbx_lua \
  --disable pbx_ael \
  --disable res_config_sqlite3 \
  menuselect.makeopts

### --- IMPORTANT: AMD SUPPORT ---
echo "[INFO] Ensuring AMD is enabled"
$MENUSELECT_BIN --enable app_amd menuselect.makeopts

### --- BUILD ---
echo "[INFO] Compiling Asterisk (this may take a while)"
make -j"$(nproc)"

### --- MARK BUILD COMPLETE ---
touch "$ASTERISK_SRC/.vicidial_built"

echo "================================================="
echo "[SUCCESS] Asterisk build completed"
echo "Marker file: $ASTERISK_SRC/.vicidial_built"
echo "================================================="

echo "[INFO] Next step: 05-install-asterisk.sh"

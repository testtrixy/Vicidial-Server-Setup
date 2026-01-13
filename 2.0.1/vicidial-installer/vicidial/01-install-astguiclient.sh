#!/usr/bin/env bash
set -euo pipefail

############################################
# Install astguiclient (Vicidial Core)
# Rocky 9 + Asterisk 18
############################################

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/vicidial-installer.log"

exec > >(tee -a "$LOG_FILE") 2>&1

ASTGUI_SRC="/usr/share/astguiclient"
ASTGUI_GIT="https://github.com/ccabrerar/vicidial.git"
ASTGUI_BRANCH="master"

ASTERISK_ETC="/etc/asterisk"
ASTGUI_CONF="/etc/astguiclient.conf"

SERVER_IP=$(hostname -I | awk '{print $1}')

echo "================================================="
echo "[$SCRIPT_NAME] Installing astguiclient"
echo "================================================="

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Must be run as root"
  exit 1
fi

### --- DEPENDENCIES ---
echo "[INFO] Installing Perl dependencies"
dnf install -y \
  perl \
  perl-DBI \
  perl-DBD-MySQL \
  perl-Time-HiRes \
  perl-libwww-perl \
  perl-LWP-Protocol-https \
  perl-GD \
  perl-JSON \
  git

### --- CLEAN OLD INSTALL ---
if [[ -d "$ASTGUI_SRC" ]]; then
  echo "[INFO] Removing existing astguiclient"
  rm -rf "$ASTGUI_SRC"
fi

### --- CLONE ASTGUICLIENT ---
echo "[INFO] Cloning Vicidial repository"
git clone --depth 1 --branch "$ASTGUI_BRANCH" "$ASTGUI_GIT" "$ASTGUI_SRC"

### --- SET PERMISSIONS ---
chown -R asterisk:asterisk "$ASTGUI_SRC"
chmod -R 755 "$ASTGUI_SRC"

### --- CREATE ASTGUICLIENT.CONF ---
if [[ ! -f "$ASTGUI_CONF" ]]; then
  echo "[INFO] Creating /etc/astguiclient.conf"
  cat > "$ASTGUI_CONF" <<EOF
PATHhome=/usr/share/astguiclient
PATHlogs=/var/log/astguiclient
PATHagi=/var/lib/asterisk/agi-bin
PATHweb=/var/www/html
PATHsounds=/var/lib/asterisk/sounds
PATHmonitor=/var/spool/asterisk/monitor
PATHDONEmonitor=/var/spool/asterisk/monitorDONE

VARserver_ip=$SERVER_IP

VARDB_server=localhost
VARDB_database=asterisk
VARDB_user=cron
VARDB_pass=1234
VARDB_port=3306

VARASTMANAGER_user=cron
VARASTMANAGER_pass=$(grep VARASTMANAGER_pass /etc/astguiclient.conf | cut -d= -f2 || true)
VARASTMANAGER_server=127.0.0.1
VARASTMANAGER_port=5038
EOF
fi

chmod 640 "$ASTGUI_CONF"
chown root:asterisk "$ASTGUI_CONF"

### --- SYMLINK AGI SCRIPTS ---
echo "[INFO] Linking AGI scripts"
ln -sf "$ASTGUI_SRC/agi-bin"/* /var/lib/asterisk/agi-bin/

### --- INITIAL DIALPLAN GENERATION ---
echo "[INFO] Generating Vicidial dialplan"
perl "$ASTGUI_SRC/AST_update.pl" --debug || true

### --- INCLUDE VICIDIAL IN EXTENSIONS.CONF ---
if ! grep -q "extensions-vicidial.conf" "$ASTERISK_ETC/extensions.conf"; then
  echo "[INFO] Including extensions-vicidial.conf"
  cat >> "$ASTERISK_ETC/extensions.conf" <<EOF

; === VICIDIAL DIALPLAN ===
#include "$ASTERISK_ETC/extensions-vicidial.conf"
EOF
fi

### --- RELOAD ASTERISK ---
echo "[INFO] Reloading Asterisk"
asterisk -rx "dialplan reload" || true

### --- VERIFY ---
echo "[CHECK] Dialplan verification"
asterisk -rx "dialplan show vicidial_conf" || true

echo "================================================="
echo "[SUCCESS] astguiclient installed"
echo "================================================="

#!/usr/bin/env bash
set -euo pipefail

############################################
# Install Asterisk 18 into system
# Rocky Linux 9 + Vicidial
############################################

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/vicidial-installer.log"

exec > >(tee -a "$LOG_FILE") 2>&1

ASTERISK_SRC="/usr/src/asterisk"
ASTERISK_USER="asterisk"
ASTERISK_GROUP="asterisk"

echo "================================================="
echo "[$SCRIPT_NAME] Installing Asterisk"
echo "================================================="

### --- SAFETY CHECKS ---
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Must be run as root"
  exit 1
fi

if [[ ! -f "$ASTERISK_SRC/.vicidial_built" ]]; then
  echo "[ERROR] Asterisk not built yet (missing .vicidial_built)"
  exit 1
fi

cd "$ASTERISK_SRC"

### --- CREATE USER/GROUP ---
if ! id "$ASTERISK_USER" &>/dev/null; then
  echo "[INFO] Creating asterisk user/group"
  groupadd -r "$ASTERISK_GROUP"
  useradd -r -g "$ASTERISK_GROUP" -d /var/lib/asterisk -s /sbin/nologin "$ASTERISK_USER"
fi

### --- INSTALL BINARIES ---
echo "[INFO] Installing Asterisk binaries"
make install

### --- INSTALL SAMPLE CONFIGS (SAFE MODE) ---
if [[ ! -d /etc/asterisk ]]; then
  echo "[INFO] Installing sample configuration files"
  make samples
else
  echo "[INFO] /etc/asterisk already exists — skipping samples"
fi

### --- INSTALL SYSTEMD SERVICE ---
echo "[INFO] Installing systemd service"
make config
ldconfig

systemctl daemon-reexec
systemctl daemon-reload

### --- DIRECTORY PERMISSIONS ---
echo "[INFO] Fixing permissions"

mkdir -p \
  /var/run/asterisk \
  /var/log/asterisk \
  /var/spool/asterisk \
  /var/lib/asterisk \
  /var/lib/asterisk/sounds \
  /var/lib/asterisk/agi-bin

chown -R "$ASTERISK_USER:$ASTERISK_GROUP" \
  /var/run/asterisk \
  /var/log/asterisk \
  /var/spool/asterisk \
  /var/lib/asterisk \
  /etc/asterisk

chmod -R 750 /var/{run,log,spool}/asterisk
chmod -R 750 /etc/asterisk

### --- SET ASTERISK USER/GROUP ---
echo "[INFO] Configuring asterisk.conf user/group"

sed -i \
  -e "s/^;runuser =.*/runuser = ${ASTERISK_USER}/" \
  -e "s/^;rungroup =.*/rungroup = ${ASTERISK_GROUP}/" \
  /etc/asterisk/asterisk.conf

### --- DISABLE REMOTE AMI BY DEFAULT ---
echo "[INFO] Locking AMI bind address"

sed -i \
  -e 's/^bindaddr=.*/bindaddr=127.0.0.1/' \
  /etc/asterisk/manager.conf || true

### --- ENABLE ASTERISK SERVICE ---
echo "[INFO] Enabling Asterisk service"
systemctl enable asterisk

### --- DO NOT START YET ---
echo "[INFO] Asterisk installed but NOT started (Vicidial not ready)"

touch /etc/asterisk/.installed_by_vicidial

echo "================================================="
echo "[SUCCESS] Asterisk installation complete"
echo "================================================="

echo "[INFO] Next steps:"
echo " - Apply modules.conf auto-generator"
echo " - AMI hardening"
echo " - Vicidial / astguiclient install"

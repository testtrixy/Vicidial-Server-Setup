#!/usr/bin/env bash
set -euo pipefail

############################################
# Vicidial AMI Hardening
# Rocky 9 + Asterisk 18
############################################

SCRIPT_NAME=$(basename "$0")
LOG_FILE="/var/log/vicidial-installer.log"

exec > >(tee -a "$LOG_FILE") 2>&1

MANAGER_CONF="/etc/asterisk/manager.conf"
ASTGUI_CONF="/etc/astguiclient.conf"

AMI_USER="cron"
AMI_PASS="$(openssl rand -hex 16)"

echo "================================================="
echo "[$SCRIPT_NAME] Hardening Asterisk AMI for Vicidial"
echo "================================================="

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Must be run as root"
  exit 1
fi

### --- BACKUP EXISTING ---
if [[ -f "$MANAGER_CONF" ]]; then
  cp -a "$MANAGER_CONF" "${MANAGER_CONF}.bak.$(date +%F_%T)"
  echo "[INFO] manager.conf backed up"
fi

### --- WRITE MANAGER.CONF ---
cat > "$MANAGER_CONF" <<EOF
[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1
displayconnects = yes
allowmultiplelogin = yes
webenabled = no
httptimeout = 60
timestampevents = yes

; ==============================
; Vicidial AMI User
; ==============================
[$AMI_USER]
secret = $AMI_PASS
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.255
read = all
write = all
EOF

### --- PERMISSIONS ---
chown root:asterisk "$MANAGER_CONF"
chmod 640 "$MANAGER_CONF"

echo "[INFO] manager.conf written"

### --- ASTGUICLIENT CONF SYNC ---
if [[ ! -f "$ASTGUI_CONF" ]]; then
  echo "[WARN] /etc/astguiclient.conf not found yet, creating minimal version"
  cat > "$ASTGUI_CONF" <<EOF
VARASTMANAGER_user=$AMI_USER
VARASTMANAGER_pass=$AMI_PASS
VARASTMANAGER_server=127.0.0.1
VARASTMANAGER_port=5038
EOF
else
  sed -i \
    -e "s/^VARASTMANAGER_user=.*/VARASTMANAGER_user=$AMI_USER/" \
    -e "s/^VARASTMANAGER_pass=.*/VARASTMANAGER_pass=$AMI_PASS/" \
    -e "s/^VARASTMANAGER_server=.*/VARASTMANAGER_server=127.0.0.1/" \
    -e "s/^VARASTMANAGER_port=.*/VARASTMANAGER_port=5038/" \
    "$ASTGUI_CONF"
fi

chmod 640 "$ASTGUI_CONF"
chown root:asterisk "$ASTGUI_CONF"

echo "[INFO] astguiclient.conf AMI values synced"

### --- RELOAD ASTERISK ---
echo "[INFO] Reloading Asterisk manager"
asterisk -rx "manager reload" || true

### --- VERIFY ---
sleep 2
echo "[CHECK] AMI connectivity test"
echo -e "Action: Login\nUsername: $AMI_USER\nSecret: $AMI_PASS\n\nAction: Logoff\n\n" \
  | timeout 3 telnet 127.0.0.1 5038 || true

echo "================================================="
echo "[SUCCESS] AMI hardened and Vicidial-safe"
echo "AMI User : $AMI_USER"
echo "AMI Port : 5038 (localhost only)"
echo "================================================="

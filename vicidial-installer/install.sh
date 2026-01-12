#!/bin/bash
set -euo pipefail


echo "=============================="
echo " VICIDIAL AUTO INSTALL Script "
echo "=============================="



#-----------------------------------------

LOG_FILE="/var/log/vicidial-installer.log"
mkdir -p /var/log

exec > >(tee -a "$LOG_FILE") 2>&1

#----------------------------------------

if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi


echo "=================================================="
echo " VICIDIAL INSTALLER STARTED: $(date)"
echo "=================================================="

# ---------------------------------------------------
# Global SERVER_IP detection (used by multiple steps)
# ---------------------------------------------------

if [ -n "${PUBLIC_IP:-}" ]; then
  SERVER_IP="$PUBLIC_IP"
else
  SERVER_IP=$(hostname -I | awk '{print $1}')

  # If private IP, try public detection (cloud-safe)
  if echo "$SERVER_IP" | grep -Eq '^10\.|^192\.168|^172\.(1[6-9]|2[0-9]|3[0-1])'; then
    SERVER_IP=$(curl -s https://ifconfig.me || true)
  fi
fi

if [ -z "${SERVER_IP:-}" ]; then
  echo "[FATAL] SERVER_IP could not be determined"
  exit 1
fi

export SERVER_IP
echo "[+] Using SERVER_IP=$SERVER_IP"

# ---------------------------------------------------
# VICIdial Installer — Rollback Safety Gate
# ---------------------------------------------------

STATE_DIR="${STATE_DIR:-/var/lib/vicidial-installer}"
ROLLBACK_MARKER="$STATE_DIR/ROLLBACK_IN_PROGRESS"

if [ -f "$ROLLBACK_MARKER" ]; then
  echo "=================================================="
  echo "[FATAL] Rollback is in progress or incomplete."
  echo "Marker file found: $ROLLBACK_MARKER"
  echo ""
  echo "Do NOT run install.sh until rollback is completed."
  echo ""
  echo "If rollback crashed, fix or re-run rollback.sh:"
  echo "  ./rollback.sh"
  echo "=================================================="
  exit 1
fi




trap 'set +e; ./rollback.sh || true; exit 1' ERR

set -e

source ./config.env

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install-$(date +%F_%T).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=============================="
echo " VICIDIAL AUTO INSTALL START "
echo "=============================="

STEPS=(
  "00-env-check.sh"
  "01-os-prep.sh"
  "02-repos-packages.sh"
  "03-mariadb.sh"
  "04-perl.sh"
  "05-libs-codecs.sh"
  "06-dahdi.sh"
  "07-asterisk.sh"
  "08-vicidial.sh"
  "09-boot-cron.sh"
  "09A-web-tuning.sh"
  "10-fail2ban.sh"
)

trap 'echo "[ERROR] Install failed — rolling back"; ./rollback.sh' ERR


mkdir -p "$STATE_DIR"

for STEP in "${STEPS[@]}"; do
  STATE_FILE="$STATE_DIR/$STEP.done"

  echo "----------------------------------"
  if [ -f "$STATE_FILE" ]; then
    echo "[SKIP] $STEP already completed"
  else
    echo "[RUNNING] $STEP"
    bash "./steps/$STEP"
    touch "$STATE_FILE"
    echo "[OK] $STEP completed"
  fi
done






# ---------------------------------------------------
# Force-correct server_ip everywhere (idempotent)
# ---------------------------------------------------



mysql -u root ${DB_NAME} <<EOF
UPDATE servers
  SET server_ip='${SERVER_IP}',
      active_twin_server_ip='${SERVER_IP}';

UPDATE system_settings
  SET active_voicemail_server='${SERVER_IP}';

UPDATE phones
  SET server_ip='${SERVER_IP}'
  WHERE server_ip='' OR server_ip='127.0.0.1';

UPDATE vicidial_conferences
  SET server_ip='${SERVER_IP}'
  WHERE server_ip='' OR server_ip='127.0.0.1';

UPDATE vicidial_confbridges
  SET server_ip='${SERVER_IP}'
  WHERE server_ip='' OR server_ip='127.0.0.1';

UPDATE vicidial_inbound_dids
  SET server_ip='${SERVER_IP}',
      filter_server_ip='${SERVER_IP}';

UPDATE vicidial_server_trunks
  SET server_ip='${SERVER_IP}';

UPDATE vicidial_server_carriers
  SET server_ip='${SERVER_IP}';

UPDATE servers SET rebuild_conf_files='Y';
EOF

echo "[OK] server_ip normalized across database"






echo "Running health check..."
bash ./health-check.sh




echo "=================================================="
echo " VICIDIAL INSTALLER Ended: $(date)"
echo "=================================================="

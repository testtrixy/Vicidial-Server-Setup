#!/bin/bash




if [ "$EUID" -ne 0 ]; then
  echo "Run as root"
  exit 1
fi


echo "=============================="
echo " VICIDIAL AUTO INSTALL Script "
echo "=============================="

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



echo "=============================="
echo " INSTALL COMPLETED SUCCESSFULLY "
echo "=============================="

echo "Running health check..."
bash ./health-check.sh

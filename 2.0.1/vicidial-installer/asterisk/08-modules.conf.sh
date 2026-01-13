#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " Generating modules.conf (Vicidial)"
echo "========================================"

TEMPLATE="templates/asterisk/modules.conf.tpl"
DEST="/etc/asterisk/modules.conf"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "[FATAL] Template missing: $TEMPLATE"
  exit 1
fi

mkdir -p /etc/asterisk

cp -f "$TEMPLATE" "$DEST"
chown root:asterisk "$DEST"
chmod 640 "$DEST"

echo "[INFO] Reloading Asterisk modules"
asterisk -rx "module reload" || true

echo "[OK] modules.conf applied"

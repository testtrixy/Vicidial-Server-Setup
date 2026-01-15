#!/usr/bin/env bash
set -euo pipefail

echo "[ROLLBACK] Stage 04 – Telephony (Asterisk / DAHDI)"

if systemctl list-unit-files | grep -q '^asterisk\.service'; then
  systemctl stop asterisk || true
  systemctl disable asterisk || true
  echo "Stopped and disabled Asterisk service"
fi

# Remove compiled artifacts only
rm -rf /usr/lib64/asterisk || true
rm -rf /var/lib/asterisk || true
rm -rf /var/spool/asterisk || true
rm -rf /etc/asterisk || true
rm -f  /usr/sbin/asterisk || true

# IMPORTANT:
# Do NOT remove:
# - kernel-devel
# - kernel-headers
# - gcc / make
# - system libraries

echo "[ROLLBACK] Stage 04 completed safely"
exit 0

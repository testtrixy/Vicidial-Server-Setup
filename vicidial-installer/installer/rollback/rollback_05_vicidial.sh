#!/usr/bin/env bash
set -euo pipefail

echo "[ROLLBACK] Stage 05 – Vicidial Core"

# Remove Vicidial cron jobs only
if command -v crontab >/dev/null; then
  crontab -l 2>/dev/null | grep -v astguiclient | crontab - || true
  echo "Removed Vicidial cron entries"
fi

# Remove Vicidial application files
rm -rf /usr/share/astguiclient || true
rm -rf /var/log/astguiclient || true
rm -rf /var/www/html/vicidial || true
rm -f  /etc/astguiclient.conf || true

# IMPORTANT:
# Do NOT:
# - uninstall Perl modules
# - remove MariaDB client
# - remove Asterisk binaries

echo "[ROLLBACK] Stage 05 completed safely"
exit 0

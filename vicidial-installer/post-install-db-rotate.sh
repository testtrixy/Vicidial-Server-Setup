#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.env"

echo "=================================================="
echo " POST-INSTALL: DB PASSWORD ROTATION"
echo "=================================================="

# Safety guard
[ -z "$DB_PASS_CRON" ] && { echo "[FATAL] DB_PASS_CRON not set"; exit 1; }
[ -z "$DB_PASS_CUSTOM" ] && { echo "[FATAL] DB_PASS_CUSTOM not set"; exit 1; }

echo "[+] Rotating MySQL passwords"

mysql -u root <<EOF
ALTER USER '${DB_USER_CRON}'@'localhost'
  IDENTIFIED BY '${DB_PASS_CRON}';
ALTER USER '${DB_USER_CUSTOM}'@'localhost'
  IDENTIFIED BY '${DB_PASS_CUSTOM}';
FLUSH PRIVILEGES;
EOF

echo "[+] Updating /etc/astguiclient.conf"

sed -i \
  -e "s/^VARDB_pass=.*/VARDB_pass=${DB_PASS_CRON}/" \
  /etc/astguiclient.conf

# Optional: update reports/custom configs if present
[ -f /etc/astguiclient.conf.custom ] && \
  sed -i \
    -e "s/^VARDB_pass=.*/VARDB_pass=${DB_PASS_CUSTOM}/" \
    /etc/astguiclient.conf.custom || true

echo "[+] Verifying DB connectivity with rotated password"

mysql -u "${DB_USER_CRON}" -p"${DB_PASS_CRON}" "${DB_NAME}" \
  -e "SELECT 1;" >/dev/null \
  || { echo "[FATAL] DB auth failed after rotation"; exit 1; }

echo "[OK] DB password rotation completed successfully"
echo "=================================================="

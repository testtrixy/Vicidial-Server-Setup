#!/usr/bin/env bash
set -euo pipefail

echo "[ROLLBACK] Stage 02 – Web / Database"

VICIDIAL_CNF="/etc/my.cnf.d/vicidial.cnf"

if systemctl list-unit-files | grep -q '^mariadb\.service'; then
  systemctl stop mariadb || true
  echo "Stopped MariaDB service"
fi

if [[ -f "${VICIDIAL_CNF}" ]]; then
  rm -f "${VICIDIAL_CNF}"
  echo "Removed Vicidial MariaDB configuration"
fi

# IMPORTANT:
# Do NOT:
# - delete databases
# - delete users
# - uninstall MariaDB packages

echo "[ROLLBACK] Stage 02 completed safely"
exit 0

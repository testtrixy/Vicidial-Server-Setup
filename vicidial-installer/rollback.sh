#!/bin/bash
set -euo pipefail

# ---------------------------------------------------
# VICIdial Installer — SAFE ROLLBACK
# ---------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR" && pwd)"

# Load config if present
[ -f "$ROOT_DIR/config.env" ] && source "$ROOT_DIR/config.env"

STATE_DIR="${STATE_DIR:-/var/lib/vicidial-installer}"
ROLLBACK_MARKER="$STATE_DIR/ROLLBACK_IN_PROGRESS"

# Optional flags
# export CLEAN_DB=1   -> drop DB if possible
CLEAN_DB="${CLEAN_DB:-0}"

AST_DB="${DB_NAME:-asterisk}"

echo "=================================================="
echo " VICIDIAL SAFE ROLLBACK STARTING"
echo "=================================================="

mkdir -p "$STATE_DIR"

# ---------------------------------------------------
# 1. Mark rollback in progress
# ---------------------------------------------------
echo "[+] Marking rollback in progress"
touch "$ROLLBACK_MARKER"

# ---------------------------------------------------
# 2. Stop services (ignore failures)
# ---------------------------------------------------
echo "[+] Stopping services"

systemctl stop asterisk 2>/dev/null || true
systemctl stop httpd 2>/dev/null || true
systemctl stop fail2ban 2>/dev/null || true
systemctl stop crond 2>/dev/null || true

# ---------------------------------------------------
# Helper: check if mariadb is running
# ---------------------------------------------------
mysql_running() {
  systemctl is-active --quiet mariadb
}

# ---------------------------------------------------
# 3 & 4. OPTIONAL: start mariadb + conditional DB cleanup
# ---------------------------------------------------
if [ "$CLEAN_DB" -eq 1 ]; then
  echo "[WARN] CLEAN_DB enabled — attempting DB cleanup"

  if ! mysql_running; then
    echo "[+] Starting MariaDB temporarily for cleanup"
    systemctl start mariadb 2>/dev/null || true
    sleep 3
  fi

  if mysql -u root -e "SELECT 1;" >/dev/null 2>&1; then
    echo "[+] Dropping database '${AST_DB}'"
    mysql -u root -e "DROP DATABASE IF EXISTS ${AST_DB};" || true
  else
    echo "[SKIP] MariaDB not reachable — skipping DB cleanup"
  fi
else
  echo "[SKIP] CLEAN_DB not enabled — preserving database"
fi

# ---------------------------------------------------
# 5. Remove installer state (.done files)
# ---------------------------------------------------
echo "[+] Removing installer state files"

rm -f "$STATE_DIR"/*.done 2>/dev/null || true

# ---------------------------------------------------
# 6. Remove source directories (SAFE)
# ---------------------------------------------------
echo "[+] Removing source directories"

rm -rf /usr/src/astguiclient 2>/dev/null || true
rm -rf /usr/src/asterisk-* 2>/dev/null || true
rm -rf /usr/src/dahdi-* 2>/dev/null || true
rm -rf /usr/src/libpri-* 2>/dev/null || true
rm -rf /usr/src/jansson-* 2>/dev/null || true
rm -rf /usr/src/lame-* 2>/dev/null || true

# ---------------------------------------------------
# 7. Remove temporary / installer-generated configs
# (DO NOT remove production configs blindly)
# ---------------------------------------------------
echo "[+] Cleaning temporary configs"

rm -f /etc/astguiclient.conf 2>/dev/null || true
rm -f /etc/astguiclient.conf.custom 2>/dev/null || true

# Apache / PHP tuning scripts are re-applied on install
rm -f /etc/httpd/conf.d/vicidial-installer.conf 2>/dev/null || true

# ---------------------------------------------------
# 8. Restart essential base services (optional)
# ---------------------------------------------------
echo "[+] Restarting base services"

systemctl start mariadb 2>/dev/null || true
systemctl start httpd 2>/dev/null || true

# ---------------------------------------------------
# 9. Clear rollback marker
# ---------------------------------------------------
echo "[+] Clearing rollback marker"
rm -f "$ROLLBACK_MARKER"



# Insert into Section 2 (Stopping services)
echo "[+] Unloading Kernel Modules"
modprobe -r dahdi_dummy 2>/dev/null || true
modprobe -r dahdi 2>/dev/null || true

# Insert into Section 7 (Cleaning configs)
echo "[+] Cleaning Crontab"
crontab -l | sed '/# VICIDIAL CRON START/,/# VICIDIAL CRON END/d' | crontab - 2>/dev/null || true

# Insert into Section 6 (Removing source)
echo "[+] Cleaning Installer Logs"
rm -rf "$LOG_DIR"/* 2>/dev/null || true




echo "=================================================="
echo " VICIDIAL ROLLBACK COMPLETED SAFELY"
echo "=================================================="

echo ""
echo "Next steps:"
echo "  • For clean rebuild: export FORCE_REBUILD_DB=1 && ./install.sh"
echo "  • For restore/retry: ./install.sh"


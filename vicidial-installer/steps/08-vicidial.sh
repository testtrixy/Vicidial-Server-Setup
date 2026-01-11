#!/bin/bash
set -euo pipefail

# ---------------------------------------------------
# STEP 08: VICIdial Core + Schema (Production Safe)
# ---------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/config.env"

echo "=================================================="
echo " STEP 08: VICIDIAL CORE INSTALLATION"
echo "=================================================="

AST_DB="$DB_NAME"
SVN_DIR="/usr/src/astguiclient"
WEB_ROOT="${WEB_ROOT:-/var/www/html}"

# Optional flag (ONLY for fresh installs / CI)
FORCE_REBUILD_DB="${FORCE_REBUILD_DB:-0}"

# ---------------------------------------------------
# Sanity checks
# ---------------------------------------------------
command -v svn >/dev/null || { echo "[FATAL] svn not installed"; exit 1; }
command -v mysql >/dev/null || { echo "[FATAL] mysql client missing"; exit 1; }

# ---------------------------------------------------
# Detect server IP (prevents server_ip='')
# ---------------------------------------------------
if [ -n "$PUBLIC_IP" ]; then
  SERVER_IP="$PUBLIC_IP"
else
  SERVER_IP=$(hostname -I | awk '{print $1}')
fi

[ -z "$SERVER_IP" ] && { echo "[FATAL] Unable to detect server IP"; exit 1; }

echo "[+] Detected server IP: $SERVER_IP"

# ---------------------------------------------------
# Checkout / update VICIdial source
# ---------------------------------------------------
cd /usr/src
if [ ! -d "$SVN_DIR/.svn" ]; then
  echo "[+] Checking out VICIdial source"
  svn checkout "$VICIDIAL_SVN" astguiclient
else
  echo "[+] Updating VICIdial source"
  cd astguiclient && svn update
fi

cd astguiclient

# ---------------------------------------------------
# Force rebuild DB (ONLY if explicitly requested)
# ---------------------------------------------------
if [ "$FORCE_REBUILD_DB" -eq 1 ]; then
  echo "[WARN] FORCE_REBUILD_DB enabled – DROPPING DATABASE"
  mysql -u root -e "DROP DATABASE IF EXISTS ${AST_DB};"
fi

# ---------------------------------------------------
# Ensure database exists
# ---------------------------------------------------
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${AST_DB}
  DEFAULT CHARACTER SET utf8
  COLLATE utf8_unicode_ci;
EOF

# ---------------------------------------------------
# CRITICAL: Create DB Users (cron/custom)
# install.pl --no-prompt defaults to password '1234'
# ---------------------------------------------------
echo "[+] Creating MySQL users (cron/custom)"

mysql -u root <<EOF
CREATE USER IF NOT EXISTS '${DB_USER_CRON}'@'localhost'
  IDENTIFIED BY '${DB_PASS_CRON}';
GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES
  ON ${AST_DB}.*
  TO '${DB_USER_CRON}'@'localhost';
GRANT RELOAD ON *.* TO '${DB_USER_CRON}'@'localhost';

CREATE USER IF NOT EXISTS '${DB_USER_CUSTOM}'@'localhost'
  IDENTIFIED BY '${DB_PASS_CUSTOM}';
GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES
  ON ${AST_DB}.*
  TO '${DB_USER_CUSTOM}'@'localhost';
GRANT RELOAD ON *.* TO '${DB_USER_CUSTOM}'@'localhost';

FLUSH PRIVILEGES;
EOF

# ---------------------------------------------------
# Schema idempotency guard
# ---------------------------------------------------
SCHEMA_PRESENT=$(mysql -u root ${AST_DB} \
  -e "SHOW TABLES LIKE 'servers';" | grep -c servers || true)

if [ "$SCHEMA_PRESENT" -eq 0 ]; then
  echo "[+] Importing VICIdial schema"
  mysql -u root ${AST_DB} < extras/MySQL_AST_CREATE_tables.sql
  mysql -u root ${AST_DB} < extras/first_server_install.sql
else
  echo "[OK] VICIdial schema already exists – skipping import"
fi

# ---------------------------------------------------
# Sanity check – ensure schema actually loaded
# ---------------------------------------------------
TABLE_COUNT=$(mysql -u root ${AST_DB} -e "SHOW TABLES;" | wc -l)

if [ "$TABLE_COUNT" -lt 50 ]; then
  echo "[FATAL] Schema import failed – only $TABLE_COUNT tables found"
  exit 1
fi

echo "[OK] Schema verification passed ($TABLE_COUNT tables)"

# ---------------------------------------------------
# Run VICIdial installer (non-interactive)
# ---------------------------------------------------
echo "[+] Running VICIdial install.pl"

perl install.pl \
  --web-root="$WEB_ROOT" \
  --no-prompt \
  --copy_sample_conf_files=y \
  --server_ip="$SERVER_IP"

# ---------------------------------------------------
# Schema version tracking
# ---------------------------------------------------
SVN_REV_LOCAL=$(svn info | awk '/Revision:/ {print $2}')
mysql -u root ${AST_DB} -e \
  "UPDATE system_settings SET svn_revision='${SVN_REV_LOCAL}';" || true

# ---------------------------------------------------
# Post-install VICIdial scripts
# ---------------------------------------------------
/usr/share/astguiclient/ADMIN_area_code_populate.pl --purge-table --debug || true
/usr/share/astguiclient/ADMIN_update_server_ip.pl --old-server_ip=127.0.0.1 || true

# ---------------------------------------------------
# Permissions safety
# ---------------------------------------------------
chown -R asterisk:asterisk /var/log/asterisk /var/spool/asterisk || true
chown -R apache:apache "$WEB_ROOT" || true
chmod -R 755 "$WEB_ROOT/vicidial" || true

# ---------------------------------------------------
# Final validation
# ---------------------------------------------------
mysql -u root ${AST_DB} \
  -e "SELECT count(*) FROM vicidial_campaigns;" >/dev/null \
  || { echo "[FATAL] VICIdial DB validation failed"; exit 1; }

echo "[OK] STEP 08 COMPLETED SUCCESSFULLY"
echo "=================================================="

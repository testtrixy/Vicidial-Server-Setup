#!/bin/bash
set -euo pipefail
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[RUNNING] $0"
source ./config.env



echo "=================================================="
echo " STEP 08: VICIDial Core"
echo "=================================================="

# Detect server IP safely
if [ -n "${PUBLIC_IP:-}" ]; then
  SERVER_IP="$PUBLIC_IP"
else
  SERVER_IP=$(hostname -I | awk '{print $1}')
  if echo "$SERVER_IP" | grep -Eq '^10\.|^192\.168|^172\.'; then
    SERVER_IP=$(curl -s https://ifconfig.me || true)
  fi
fi

[ -z "$SERVER_IP" ] && { echo "[FATAL] SERVER_IP missing"; exit 1; }
echo "[+] SERVER_IP=$SERVER_IP"

# Checkout / update VICIdial
cd /usr/src
[ -d astguiclient ] || svn checkout "$VICIDIAL_SVN" astguiclient
cd astguiclient

# Database + users
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER_CRON}'@'localhost' IDENTIFIED BY '${DB_PASS_CRON}';
CREATE USER IF NOT EXISTS '${DB_USER_CUSTOM}'@'localhost' IDENTIFIED BY '${DB_PASS_CUSTOM}';
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER_CRON}'@'localhost';
GRANT ALL ON ${DB_NAME}.* TO '${DB_USER_CUSTOM}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Schema guard
SCHEMA=$(mysql -u root ${DB_NAME} -e "SHOW TABLES LIKE 'servers'" | wc -l)
if [ "$SCHEMA" -eq 0 ]; then
  mysql -u root ${DB_NAME} < extras/MySQL_AST_CREATE_tables.sql
  mysql -u root ${DB_NAME} < extras/first_server_install.sql
fi

perl install.pl --no-prompt --copy_sample_conf_files=y --server_ip="$SERVER_IP"

mysql -u root ${DB_NAME} <<EOF
UPDATE servers SET server_ip='${SERVER_IP}', active_twin_server_ip='${SERVER_IP}';
UPDATE system_settings SET active_voicemail_server='${SERVER_IP}';
UPDATE servers SET rebuild_conf_files='Y';
EOF

# Web root (correct source)
rsync -a /usr/src/astguiclient/www/ /var/www/html/
chown -R apache:apache /var/www/html/vicidial
chmod -R 755 /var/www/html/vicidial

chown -R asterisk:asterisk /var/log/asterisk /var/spool/asterisk

echo "[OK] VICIdial core installed"

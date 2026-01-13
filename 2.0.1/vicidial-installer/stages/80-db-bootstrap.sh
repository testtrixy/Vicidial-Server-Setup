#!/usr/bin/env bash
set -Eeuo pipefail

DB_NAME=asterisk
DB_USER=cron
DB_PASS=$(openssl rand -hex 12)
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_NAME=$(hostname -s)

log INFO "Bootstrapping VICIDIAL database"

mysql <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

log INFO "Loading VICIDIAL schema"
mysql "$DB_NAME" < "$INSTALL_ROOT/sql/schema.sql"

log INFO "Registering server"
mysql "$DB_NAME" <<EOF
INSERT IGNORE INTO servers
(server_ip, server_name, active, asterisk_version, max_vicidial_trunks)
VALUES
('$SERVER_IP','$SERVER_NAME','Y','18',1000);
EOF

log INFO "Creating default admin user"
mysql "$DB_NAME" < "$INSTALL_ROOT/sql/default_users.sql"

install -m 0600 "$INSTALL_ROOT/templates/astguiclient.conf" /etc/astguiclient.conf
sed -i "s/__DB_PASS__/$DB_PASS/" /etc/astguiclient.conf

log INFO "DB bootstrap complete"

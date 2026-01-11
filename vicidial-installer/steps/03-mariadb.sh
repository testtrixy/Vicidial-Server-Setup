#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 03: MariaDB Installation & Configuration"
echo "=================================================="

# ---------------------------------------------------
# 1. Install MariaDB
# ---------------------------------------------------
dnf install -y mariadb-server mariadb

systemctl enable mariadb

# ---------------------------------------------------
# 2. Initialize DB directory if needed
# ---------------------------------------------------
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "[+] Initializing MariaDB data directory"
  mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi

# ---------------------------------------------------
# 3. Start MariaDB
# ---------------------------------------------------
systemctl start mariadb
sleep 3

# ---------------------------------------------------
# 4. Verify socket
# ---------------------------------------------------
MYSQL_SOCKET="/var/lib/mysql/mysql.sock"

if [ ! -S "$MYSQL_SOCKET" ]; then
  echo "[FATAL] MariaDB socket not found: $MYSQL_SOCKET"
  systemctl status mariadb
  exit 1
fi

echo "[OK] MariaDB socket detected"

# ---------------------------------------------------
# 5. Verify root access (socket auth)
# ---------------------------------------------------
mysql -u root -e "SELECT 1;" >/dev/null \
  || { echo "[FATAL] MariaDB root access failed"; exit 1; }

echo "[OK] MariaDB root access verified"

# ---------------------------------------------------
# 6. Secure MariaDB (NON-INTERACTIVE)
# ---------------------------------------------------
echo "[+] Hardening MariaDB"

mysql -u root <<EOF
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root'
  AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

echo "[OK] MariaDB hardened"

# ---------------------------------------------------
# 7. Calculate InnoDB buffer pool (60% RAM)
# ---------------------------------------------------
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
INNODB_BP_MB=$((TOTAL_RAM_MB * 60 / 100))

echo "[+] Total RAM: ${TOTAL_RAM_MB} MB"
echo "[+] InnoDB buffer pool: ${INNODB_BP_MB} MB"

# ---------------------------------------------------
# 8. Backup and write MariaDB config
# ---------------------------------------------------
echo "[+] Writing MariaDB configuration"

cp -n /etc/my.cnf /etc/my.cnf.original 2>/dev/null || true

cat <<EOF > /etc/my.cnf
[client]
socket=${MYSQL_SOCKET}

[mysqld]
user=mysql
datadir=/var/lib/mysql
socket=${MYSQL_SOCKET}

max_connections=800
max_allowed_packet=32M
key_buffer_size=512M
sql_mode="NO_ENGINE_SUBSTITUTION"

tmp_table_size=128M
table_cache=1024

character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# InnoDB tuning
innodb_buffer_pool_size=${INNODB_BP_MB}M
innodb_log_file_size=256M
innodb_flush_log_at_trx_commit=2
innodb_file_per_table=1

# Slow query logging
slow_query_log=1
slow_query_log_file=/var/log/mysqld/slow-queries.log
long_query_time=1
EOF

mkdir -p /var/log/mysqld
chown -R

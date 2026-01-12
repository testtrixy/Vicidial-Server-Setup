#!/bin/bash
set -euo pipefail

exec > >(tee -a "$LOG_FILE") 2>&1
echo "[RUNNING] $0"


echo "=================================================="
echo " STEP 03: MariaDB Installation & Configuration"
echo "=================================================="



MYSQL_SOCKET="/var/lib/mysql/mysql.sock"

# ---------------------------------------------------
# 1. Install MariaDB
# ---------------------------------------------------
dnf install -y mariadb-server mariadb

systemctl enable mariadb

# ---------------------------------------------------
# 2. Reset any broken previous config
# ---------------------------------------------------
echo "[+] Resetting MariaDB configuration"

if [ -f /etc/my.cnf ]; then
  mv /etc/my.cnf /etc/my.cnf.broken.$(date +%s)
fi

rm -f /etc/my.cnf.d/*.cnf 2>/dev/null || true

# ---------------------------------------------------
# 3. Initialize DB directory if needed
# ---------------------------------------------------
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "[+] Initializing MariaDB data directory"
  mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
fi

# ---------------------------------------------------
# 4. Calculate RAM-based tuning
# ---------------------------------------------------
TOTAL_RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
INNODB_BP_MB=$((TOTAL_RAM_MB * 60 / 100))

# Safe floor for small VMs
if [ "$INNODB_BP_MB" -lt 512 ]; then
  INNODB_BP_MB=512
fi

echo "[+] Total RAM: ${TOTAL_RAM_MB} MB"
echo "[+] InnoDB buffer pool: ${INNODB_BP_MB} MB"

# ---------------------------------------------------
# 5. Write MariaDB configuration (KNOWN-GOOD)
# ---------------------------------------------------
echo "[+] Writing MariaDB configuration"

cat <<EOF > /etc/my.cnf
[client]
socket=${MYSQL_SOCKET}

[mysqld]
user=mysql
datadir=/var/lib/mysql
socket=${MYSQL_SOCKET}

# Connections
max_connections=800
max_allowed_packet=32M

# MyISAM (legacy VICIdial tables)
key_buffer_size=256M

# Table cache
table_open_cache=1024
tmp_table_size=128M
max_heap_table_size=128M

# SQL mode
sql_mode=NO_ENGINE_SUBSTITUTION

# Character set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# InnoDB (primary engine)
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
chown -R mysql:mysql /var/log/mysqld

# ---------------------------------------------------
# 6. Start MariaDB with new config
# ---------------------------------------------------
echo "[+] Starting MariaDB"
systemctl restart mariadb
sleep 5

if ! systemctl is-active --quiet mariadb; then
  echo "[FATAL] MariaDB failed to start"
  journalctl -u mariadb -n 50 --no-pager
  exit 1
fi

# ---------------------------------------------------
# 7. Verify socket and query
# ---------------------------------------------------
if [ ! -S "$MYSQL_SOCKET" ]; then
  echo "[FATAL] MariaDB socket not found: $MYSQL_SOCKET"
  journalctl -u mariadb -n 50 --no-pager
  exit 1
fi

mysql -u root -e "SELECT 1;" >/dev/null \
  || { echo "[FATAL] MariaDB query test failed"; exit 1; }

echo "[OK] MariaDB started and responding"

# ---------------------------------------------------
# 8. Secure MariaDB (NON-INTERACTIVE)
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
echo "=================================================="

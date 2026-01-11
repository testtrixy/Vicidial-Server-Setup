#!/bin/bash
echo "=== STEP 03: MariaDB Setup ==="

dnf install -y mariadb-server
systemctl enable mariadb
systemctl start mariadb

echo "[+] Running mysql_secure_installation"
mysql_secure_installation


#character-set-server=utf8mb4
#collation-server=utf8mb4_unicode_ci


echo "[+] Backing up my.cnf"
cp /etc/my.cnf /etc/my.cnf.original
> /etc/my.cnf

cat <<EOF > /etc/my.cnf
[mysqld]
max_connections=800
max_allowed_packet=32M
key_buffer_size=512M
sql_mode="NO_ENGINE_SUBSTITUTION"
query-cache-size=32M
tmp_table_size=128M
table_cache=1024
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# InnoDB tuning (critical)
innodb_buffer_pool_size = 60%
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1

# Slow query logging
slow_query_log = 1
slow_query_log_file = /var/log/mysqld/slow-queries.log
long_query_time = 1

EOF

mkdir -p /var/log/mysqld
chown -R mysql:mysql /var/log/mysqld

systemctl restart mariadb

echo "[OK] MariaDB configured"

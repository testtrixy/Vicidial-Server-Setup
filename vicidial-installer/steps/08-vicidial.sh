
#!/bin/bash
echo "=== STEP 08: VICIdial ==="

cd /usr/src
svn checkout "$VICIDIAL_SVN" astguiclient || true
cd astguiclient

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS asterisk;
CREATE USER IF NOT EXISTS '$DB_USER_CRON'@'localhost' IDENTIFIED BY '$DB_PASS_CRON';
GRANT ALL ON asterisk.* TO '$DB_USER_CRON'@'localhost';
FLUSH PRIVILEGES;
EOF

perl install.pl

mysql -u root asterisk -e "SHOW TABLES;" | grep vicidial_campaigns \
  || { echo "Schema missing"; exit 1; }

/usr/share/astguiclient/ADMIN_area_code_populate.pl
/usr/share/astguiclient/ADMIN_update_server_ip.pl --old-server_ip=127.0.0.1

echo "[OK] VICIdial core installed"


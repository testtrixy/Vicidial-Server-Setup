#!/bin/bash


echo "=== ROLLBACK Starting..  ==="

if [ -f /var/lib/vicidial-installer/ROLLBACK_IN_PROGRESS ]; then
  echo "[FATAL] Rollback incomplete. Fix rollback before install."
  exit 1
fi


echo "=== ROLLBACK  ==="
echo "=== ROLLBACK  ==="

read -p "This will remove VICIdial & Asterisk. Continue? (yes/no): " ans
[ "$ans" != "yes" ] && exit 1



source ./config.env



echo "=== ROLLBACK START ==="



systemctl stop asterisk || true
systemctl stop mariadb || true
systemctl stop httpd || true

echo "Dropping Database..."
mysql -u root -e "DROP DATABASE IF EXISTS $DB_NAME;" || true


[ -f /etc/my.cnf.original ] && cp /etc/my.cnf.original /etc/my.cnf



rm -rf /usr/lib64/asterisk /var/lib/asterisk /var/log/asterisk || true
rm -rf /usr/share/astguiclient /var/www/html/vicidial || true

rm -rf "$STATE_DIR"

echo "=== ROLLBACK COMPLETE ==="

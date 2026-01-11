#!/bin/bash


echo "=== ROLLBACK  ==="
echo "=== ROLLBACK  ==="
echo "=== ROLLBACK  ==="

read -p "This will remove VICIdial & Asterisk. Continue? (yes/no): " ans
[ "$ans" != "yes" ] && exit 1



source ./config.env



echo "=== ROLLBACK START ==="

systemctl stop asterisk || true
systemctl stop mariadb || true
systemctl stop httpd || true

[ -f /etc/my.cnf.original ] && cp /etc/my.cnf.original /etc/my.cnf

rm -rf /usr/lib64/asterisk /var/lib/asterisk /var/log/asterisk || true
rm -rf /usr/share/astguiclient /var/www/html/vicidial || true

rm -rf "$STATE_DIR"

echo "=== ROLLBACK COMPLETE ==="

#!/bin/bash


read -p "This will overwrite live data. Continue? (yes/no): " ans
[ "$ans" != "yes" ] && exit 1


if [ -z "$1" ]; then
  echo "Usage: ./restore.sh <backup-dir>"
  exit 1
fi


[ ! -f "$SRC/db.sql" ] && echo "Missing db.sql" && exit 1

for f in db.sql asterisk.tar.gz vicidial.tar.gz recordings.tar.gz; do
  [ ! -f "$SRC/$f" ] && echo "Missing $f" && exit 1
done


SRC="$1"
systemctl stop asterisk mariadb httpd

mysql -u root asterisk < "$SRC/db.sql"
tar xzf "$SRC/asterisk.tar.gz" -C /
tar xzf "$SRC/vicidial.tar.gz" -C /
tar xzf "$SRC/recordings.tar.gz" -C /

systemctl restart mariadb
systemctl restart httpd
systemctl restart asterisk

echo "Restore completed"

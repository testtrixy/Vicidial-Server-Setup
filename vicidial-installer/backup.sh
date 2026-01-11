#!/bin/bash
source ./config.env

DATE=$(date +%F_%H-%M-%S)
DEST="$BACKUP_DIR/$DATE"

mkdir -p "$DEST"

#mysqldump -u root "$DB_NAME" > "$DEST/db.sql"
mysqldump --single-transaction -u root "$DB_NAME" > "$DEST/db.sql"


tar czf "$DEST/asterisk.tar.gz" /etc/asterisk /var/lib/asterisk
tar czf "$DEST/vicidial.tar.gz" /usr/share/astguiclient /var/www/html/vicidial
tar czf "$DEST/recordings.tar.gz" /var/spool/asterisk/monitorDONE # recording backup

find "$BACKUP_DIR" -type d -mtime +14 -exec rm -rf {} \; #remove old backups

find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \;


echo "Backup stored at $DEST"

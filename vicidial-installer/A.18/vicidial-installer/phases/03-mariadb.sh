#!/bin/bash
source lib/common.sh
log "Executing phase: 03-mariadb.sh"
# Logic goes here

#!/bin/bash
set -e

dnf -y install mariadb mariadb-server
systemctl enable --now mariadb

mysql <<EOF
CREATE DATABASE IF NOT EXISTS asterisk;
GRANT ALL ON asterisk.* TO 'cron'@'localhost' IDENTIFIED BY '1234';
GRANT ALL ON asterisk.* TO 'cron'@'%' IDENTIFIED BY '1234';
FLUSH PRIVILEGES;
EOF

#!/bin/bash
source lib/common.sh
log "Executing phase: 02-deps.sh"
# Logic goes here

#!/bin/bash
set -e

dnf -y groupinstall "Development Tools"
dnf -y install \
  git wget tar ncurses-devel libxml2-devel \
  openssl-devel sqlite-devel libuuid-devel \
  libcurl-devel jansson-devel mariadb-devel \
  php php-mysqlnd php-gd php-cli php-mbstring \
  httpd screen sox fail2ban perl-Time-HiRes \
  perl-DBI perl-DBD-MySQL

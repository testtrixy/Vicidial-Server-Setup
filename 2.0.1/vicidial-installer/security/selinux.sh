#!/usr/bin/env bash
set -e

setsebool -P httpd_can_network_connect 1
setsebool -P httpd_can_network_connect_db 1
setsebool -P httpd_execmem 1

semanage fcontext -a -t httpd_sys_rw_content_t "/var/spool/asterisk(/.*)?"
restorecon -Rv /var/spool/asterisk

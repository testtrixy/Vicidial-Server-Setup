#!/usr/bin/env bash
set -e

chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/log/asterisk

chmod -R 750 /var/log/asterisk
chmod -R 770 /var/spool/asterisk

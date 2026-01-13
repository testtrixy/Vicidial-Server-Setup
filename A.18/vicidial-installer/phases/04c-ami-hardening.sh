#!/bin/bash
set -e

log "Applying AMI hardening"

SRC="$BASE_DIR/config/manager.conf.template"
DST="/etc/asterisk/manager.conf"

cp -f "$SRC" "$DST"
chown asterisk:asterisk "$DST"
chmod 640 "$DST"

log "Reloading AMI"
asterisk -rx "manager reload"

# Validation
asterisk -rx "manager show settings" | grep -q "AMI: Yes" \
  || fail "AMI not enabled"

asterisk -rx "manager show settings" | grep -q "127.0.0.1" \
  || fail "AMI not bound to localhost"

log "AMI hardened and verified"

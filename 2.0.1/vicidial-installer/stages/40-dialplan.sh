#!/usr/bin/env bash
set -Eeuo pipefail

log INFO "Installing VICIDIAL dialplan base"

install -m 0644 \
  "$INSTALL_ROOT/templates/extensions.conf.base" \
  /etc/asterisk/extensions.conf

install -m 0644 \
  "$INSTALL_ROOT/templates/extensions-vicidial.conf.base" \
  /etc/asterisk/extensions-vicidial.conf

log INFO "Reloading dialplan"
asterisk -rx "dialplan reload" || true

log INFO "Dialplan base installed"

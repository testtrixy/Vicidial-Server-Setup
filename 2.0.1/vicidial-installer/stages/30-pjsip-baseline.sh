#!/usr/bin/env bash
set -Eeuo pipefail

log INFO "Installing PJSIP baseline configuration"

install -m 0644 "$INSTALL_ROOT/templates/pjsip.conf.base" /etc/asterisk/pjsip.conf

log INFO "Reloading PJSIP"
asterisk -rx "pjsip reload" || true

log INFO "PJSIP baseline installed"

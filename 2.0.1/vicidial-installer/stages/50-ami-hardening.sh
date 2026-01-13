#!/usr/bin/env bash
set -Eeuo pipefail

log INFO "Installing hardened AMI configuration"

install -m 0640 \
  "$INSTALL_ROOT/templates/manager.conf.template" \
  /etc/asterisk/manager.conf

chown root:asterisk /etc/asterisk/manager.conf

log INFO "Reloading AMI"
asterisk -rx "manager reload" || true

log INFO "AMI hardening complete"

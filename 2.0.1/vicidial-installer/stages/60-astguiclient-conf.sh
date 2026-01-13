#!/usr/bin/env bash
set -Eeuo pipefail

log INFO "Installing astguiclient.conf"

install -m 0644 \
  "$INSTALL_ROOT/templates/astguiclient.conf.template" \
  /etc/astguiclient.conf

chown root:asterisk /etc/astguiclient.conf

log INFO "astguiclient.conf installed"

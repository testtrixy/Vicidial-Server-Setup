#!/usr/bin/env bash
set -Eeuo pipefail

CONF_DIR="/etc/asterisk"
TARGET="$CONF_DIR/modules.conf"
TEMPLATE="$INSTALL_ROOT/templates/modules.conf.template"

if [[ ! -f "$TEMPLATE" ]]; then
  log ERROR "modules.conf template missing"
  exit 1
fi

log INFO "Writing $TARGET"
install -m 0644 "$TEMPLATE" "$TARGET"

log INFO "modules.conf generated successfully"

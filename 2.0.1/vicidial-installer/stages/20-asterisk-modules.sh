#!/usr/bin/env bash
set -Eeuo pipefail

log INFO "Generating Asterisk modules.conf (VICIDIAL profile)"

bash "$INSTALL_ROOT/tools/generate-modules-conf.sh"

log INFO "Reloading Asterisk modules"
asterisk -rx "module reload" || true

log INFO "Asterisk modules.conf applied"

#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="/var/log/vicidial-install.log"

exec > >(tee -a "$LOG") 2>&1

source "$BASE_DIR/config/versions.conf"
source "$BASE_DIR/lib/common.sh"
source "$BASE_DIR/lib/checks.sh"

require_root
require_rocky9

run_phase() {
  local phase="$1"
  log "=== RUNNING $phase ==="
  bash "$BASE_DIR/phases/$phase"
}

run_phase 01-os-prep.sh
run_phase 02-deps.sh
run_phase 03-mariadb.sh

run_phase 04-asterisk-build.sh
run_phase 04b-modules-conf.sh

run_phase 05-astguiclient.sh
run_phase 06-database-seed.sh
run_phase 07-dialplan-generate.sh
run_phase 08-validate.sh

log "🎉 VICIDIAL INSTALL COMPLETE"

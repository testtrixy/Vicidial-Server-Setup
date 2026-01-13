#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_ROOT="$(cd "$(dirname "$0")" && pwd)"
export INSTALL_ROOT

source "$INSTALL_ROOT/lib/common.sh"
source "$INSTALL_ROOT/lib/os_detect.sh"
source "$INSTALL_ROOT/lib/state.sh"

require_root
detect_os

log INFO "Starting VICIDIAL Next-Gen Installer"
log INFO "OS: $OS_NAME $OS_VERSION"

run_stage "00-preflight"
run_stage "01-os-hardening"

log SUCCESS "Generation 0 + 1 completed successfully"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_root
log_warn "ROLLBACK: Stage 01 – OS Base (limited rollback)"

rm -f "${MARKER_DIR}/reboot_required"
rm -f "${MARKER_DIR}/phase_01_complete"

log_warn "Kernel, SELinux, and sysctl changes are NOT reverted automatically"
log_success "Stage 01 rollback completed (limited)"

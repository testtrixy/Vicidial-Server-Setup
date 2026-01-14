#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/rollback_header.sh"


require_root
log_warn "ROLLBACK: Stage 07 – Audio & Sounds"

rm -rf /var/lib/asterisk/sounds
rm -rf /var/lib/asterisk/moh

rm -f "${MARKER_DIR}/phase_07_complete"
log_success "Stage 07 rollback completed"

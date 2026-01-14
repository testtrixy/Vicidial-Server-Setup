#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/rollback_header.sh"

require_root
log_warn "ROLLBACK: Stage 05 – Vicidial Core"

rm -rf /usr/share/astguiclient
rm -f /etc/astguiclient.conf

mysql -e "DROP DATABASE IF EXISTS asterisk;" || true

rm -f "${MARKER_DIR}/phase_05_complete"
log_success "Stage 05 rollback completed"

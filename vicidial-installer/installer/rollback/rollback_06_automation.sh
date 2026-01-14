#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_root
log_warn "ROLLBACK: Stage 06 – Automation"

crontab -r || true

rm -rf /etc/systemd/system/asterisk.service.d
systemctl daemon-reload

rm -f "${MARKER_DIR}/phase_06_complete"
log_success "Stage 06 rollback completed"

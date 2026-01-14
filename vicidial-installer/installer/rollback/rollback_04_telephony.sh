#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_root
log_warn "ROLLBACK: Stage 04 – Telephony Core"

systemctl stop asterisk || true
systemctl disable asterisk || true

dnf -y remove asterisk\* dahdi\* libpri\* libsrtp\* || true

rm -rf /etc/asterisk
rm -rf /var/lib/asterisk
rm -rf /usr/lib64/asterisk
rm -rf /usr/src/asterisk*

rm -f "${MARKER_DIR}/phase_04_complete"
log_success "Stage 04 rollback completed"

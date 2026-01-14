#!/usr/bin/env bash
set -euo pipefail

#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../lib/rollback_header.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_root
log_warn "ROLLBACK: Stage 03 – Build Environment"

dnf -y groupremove "Development Tools" || true
dnf -y remove kernel-devel\* kernel-headers\* || true

rm -f "${MARKER_DIR}/phase_03_complete"
log_success "Stage 03 rollback completed"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_root
log_warn "ROLLBACK: Stage 08 – Modern Extras"

rm -f /etc/httpd/conf.d/99-vicidial-https.conf
rm -f /etc/httpd/conf.d/99-security-headers.conf

dnf -y remove certbot fail2ban node_exporter || true

rm -f "${MARKER_DIR}/phase_08_complete"
log_success "Stage 08 rollback completed"

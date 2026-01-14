#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_root
log_warn "ROLLBACK: Stage 02 – Web & Database"

log_info "Stopping services"
systemctl stop mariadb httpd || true
systemctl disable mariadb httpd || true

log_info "Removing MariaDB & Apache packages"
dnf -y remove mariadb-server mariadb-backup mariadb-devel httpd php\* || true

log_warn "Removing MariaDB data directory"
rm -rf /var/lib/mysql

log_info "Removing MariaDB repository"
rm -f /etc/yum.repos.d/mariadb.repo

rm -f "${MARKER_DIR}/phase_02_complete"
log_success "Stage 02 rollback completed"

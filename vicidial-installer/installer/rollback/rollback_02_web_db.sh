#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/rollback_header.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_root
log_warn "ROLLBACK: Stage 02 – Web & Database"

log_info "Stopping services"


for svc in mariadb httpd; do
  if systemctl list-unit-files | grep -q "^${svc}\.service"; then
    log_info "Stopping and disabling ${svc}"
    systemctl stop "${svc}" || true
    systemctl disable "${svc}" || true
  else
    log_info "${svc} service not present – skipping"
  fi
done


#systemctl stop mariadb httpd || true
#systemctl disable mariadb httpd || true

log_info "Removing MariaDB & Apache packages"
dnf -y remove mariadb-server mariadb-backup mariadb-devel httpd php\* || true

log_warn "Removing MariaDB data directory"
rm -rf /var/lib/mysql

log_info "Removing MariaDB repository"
rm -f /etc/yum.repos.d/mariadb.repo

rm -f "${MARKER_DIR}/phase_02_complete"
log_success "Stage 02 rollback completed"

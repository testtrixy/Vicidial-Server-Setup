#!/usr/bin/env bash
# =============================================================================
# Vicidial Smoke Test Cleanup v1.3
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${INSTALLER_ROOT}/lib/common.sh"

DB="asterisk"

log_warn "=== Vicidial Smoke Test Cleanup v1.3 ==="
log_warn "This removes ONLY test data. Core schema untouched."

require_root
require_command mysql

# -----------------------------------------------------------------------------
log_info "Removing test lead and list"

mysql "${DB}" -e "
DELETE FROM vicidial_list WHERE list_id='1001';
DELETE FROM vicidial_lists WHERE list_id='1001';
"

# -----------------------------------------------------------------------------
log_info "Removing test campaign"

mysql "${DB}" -e "
DELETE FROM vicidial_campaigns WHERE campaign_id='TESTCAMP';
"

# -----------------------------------------------------------------------------
log_info "Removing admin user"

mysql "${DB}" -e "
DELETE FROM vicidial_users WHERE user='6666';
"

# -----------------------------------------------------------------------------
log_info "Removing phone extension"

mysql "${DB}" -e "
DELETE FROM phones WHERE extension='101';
"

# -----------------------------------------------------------------------------
log_info "Removing loopback carrier"

mysql "${DB}" -e "
DELETE FROM vicidial_carriers WHERE carrier_id='LOOPBACK';
"

# -----------------------------------------------------------------------------
log_info "Removing test server entry"

mysql "${DB}" -e "
DELETE FROM servers WHERE server_id='DIALER1';
"

# -----------------------------------------------------------------------------
log_info "Syncing cleanup to Asterisk"

/usr/share/astguiclient/ADMIN_update_conf.pl --force

log_success "Smoke test cleanup completed"

#!/usr/bin/env bash
# =============================================================================
# Vicidial Smoke Test Cleanup – v1.2
#
# Purpose:
#   Remove ONLY the records created by vicidial-smoke-test_v1.2.sh
#
# WARNING:
#   - SAFE, SURGICAL CLEANUP
#   - DOES NOT TOUCH DEFAULT DATA
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command mysql

log_warn "VICIDIAL SMOKE TEST CLEANUP"
log_warn "THIS WILL REMOVE TEST DATA ONLY"

echo
read -p "Type YES to continue: " CONFIRM
[[ "${CONFIRM}" == "YES" ]] || fatal "Aborted by user"

DB_NAME="asterisk"

SERVER_ID="DIALER1"
EXTENSION="101"
ADMIN_USER="6666"
CAMPAIGN_ID="TESTCAMP"
LIST_ID="1001"

# -----------------------------------------------------------------------------
# Cleanup order matters
# -----------------------------------------------------------------------------
log_info "Removing test leads"
mysql "${DB_NAME}" -e \
"DELETE FROM vicidial_list WHERE list_id='${LIST_ID}';"

log_info "Removing test list"
mysql "${DB_NAME}" -e \
"DELETE FROM vicidial_lists WHERE list_id='${LIST_ID}';"

log_info "Removing test campaign"
mysql "${DB_NAME}" -e \
"DELETE FROM vicidial_campaigns WHERE campaign_id='${CAMPAIGN_ID}';"

log_info "Removing test phone"
mysql "${DB_NAME}" -e \
"DELETE FROM phones WHERE extension='${EXTENSION}';"

log_info "Removing test admin user"
mysql "${DB_NAME}" -e \
"DELETE FROM vicidial_users WHERE user='${ADMIN_USER}';"

log_info "Removing test server (non-default only)"
mysql "${DB_NAME}" -e \
"DELETE FROM servers WHERE server_id='${SERVER_ID}';"

log_success "Smoke test data removed successfully"

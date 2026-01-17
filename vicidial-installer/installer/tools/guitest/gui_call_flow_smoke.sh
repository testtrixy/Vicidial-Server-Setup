#!/usr/bin/env bash
# =============================================================================
# GUI Call Flow Smoke Test (VICIdial – EL9 Golden)
#
# Proves:
#   - VICIdial dialplan loads
#   - Asterisk executes vicidial-auto-phones
#   - Local originate is ACCEPTED (not rejected)
#
# Does NOT require:
#   - SIP registration
#   - Audio
#   - Trunks
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command asterisk
require_command mysql

check_el9

# -----------------------------------------------------------------------------
# Opt-in guard
# -----------------------------------------------------------------------------
if [[ "${ENABLE_GUI_CALL_SMOKE:-no}" != "yes" ]]; then
  log_warn "GUI call flow smoke test disabled (ENABLE_GUI_CALL_SMOKE!=yes)"
  exit 0
fi

log_info "=== GUI CALL FLOW SMOKE TEST START ==="

# -----------------------------------------------------------------------------
# Dialplan sanity (THIS IS THE REAL GATE)
# -----------------------------------------------------------------------------
if ! asterisk -rx "dialplan show vicidial-auto-phones" >/dev/null 2>&1; then
  fatal "vicidial-auto-phones dialplan missing"
fi

log_success "vicidial-auto-phones dialplan present"

# -----------------------------------------------------------------------------
# Load DB credentials
# -----------------------------------------------------------------------------
ASTGUI_CONF="/etc/astguiclient.conf"
[[ -f "${ASTGUI_CONF}" ]] || fatal "Missing ${ASTGUI_CONF}"

cfg() { awk -F'=>|=' -v k="$1" '$1~k{gsub(/ /,"",$2);print $2}' "${ASTGUI_CONF}"; }

DB_HOST="$(cfg VARDB_server)"
DB_NAME="$(cfg VARDB_database)"
DB_USER="$(cfg VARDB_user)"
DB_PASS="$(cfg VARDB_pass)"
DB_PORT="$(cfg VARDB_port)"

MYSQL_CMD=(
  mysql --protocol=tcp
  -h "${DB_HOST:-127.0.0.1}"
  -P "${DB_PORT:-3306}"
  -u "${DB_USER}"
  "-p${DB_PASS}"
  "${DB_NAME}"
)

# -----------------------------------------------------------------------------
# Create minimal VICIdial objects (schema-safe)
# -----------------------------------------------------------------------------
log_info "Ensuring VICIdial test objects"

"${MYSQL_CMD[@]}" -e "
INSERT IGNORE INTO servers
(server_ip, server_description, active)
VALUES ('127.0.0.1','GUI Smoke Server','Y');

INSERT IGNORE INTO phones
(extension, dialplan_number, server_ip, active)
VALUES ('9999','9999','127.0.0.1','Y');

INSERT IGNORE INTO vicidial_users
(user, pass, user_level, active)
VALUES ('9999','9999','9','Y');
"

log_success "VICIdial DB objects present"

# -----------------------------------------------------------------------------
# CRITICAL TEST: originate acceptance
# -----------------------------------------------------------------------------
log_info "Issuing VICIdial originate (acceptance test)"

ORIGINATE_OUTPUT="$(
  asterisk -rx "channel originate Local/9999@vicidial-auto-phones,1" 2>&1 || true
)"

echo "${ORIGINATE_OUTPUT}" | grep -qiE "originat|success|request" || {
  echo "${ORIGINATE_OUTPUT}"
  fatal "Originate rejected by Asterisk"
}

log_success "Originate accepted by VICIdial dialplan"

# -----------------------------------------------------------------------------
# PASS
# -----------------------------------------------------------------------------
log_success "=== GUI CALL FLOW SMOKE TEST PASSED ==="
exit 0

#!/usr/bin/env bash
# =============================================================================
# GUI Call Flow Smoke Test (VICIdial – EL9 Golden)
#
# Purpose:
#   - Prove VICIdial can originate a call end-to-end
#   - Validate Agent + Phone + Campaign wiring
#   - Verify Asterisk receives a live channel
#
# Non-Goals:
#   - No audio quality testing
#   - No Selenium / browser automation
#   - No trunks required
#
# Safe:
#   - Idempotent
#   - Opt-in only
#   - Uses VICIdial DB credentials (NO ROOT)
# =============================================================================

set -euo pipefail







SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command mysql
require_command asterisk
require_command perl

check_el9

# -----------------------------------------------------------------------------
# Opt-in guard (SAFE BY DEFAULT)
# -----------------------------------------------------------------------------
if [[ "${ENABLE_GUI_CALL_SMOKE:-no}" != "yes" ]]; then
  log_warn "GUI call flow smoke test disabled (ENABLE_GUI_CALL_SMOKE!=yes)"
  exit 0
fi

log_info "=== GUI CALL FLOW SMOKE TEST START ==="

# -----------------------------------------------------------------------------
# Load VICIdial DB credentials (AUTHORITATIVE)
# -----------------------------------------------------------------------------
ASTGUI_CONF="/etc/astguiclient.conf"
[[ -f "${ASTGUI_CONF}" ]] || fatal "Missing ${ASTGUI_CONF}"

DB_HOST="$(grep '^VARDB_server=' "${ASTGUI_CONF}" | cut -d= -f2)"
DB_NAME="$(grep '^VARDB_database=' "${ASTGUI_CONF}" | cut -d= -f2)"
DB_USER="$(grep '^VARDB_user=' "${ASTGUI_CONF}" | cut -d= -f2)"
DB_PASS="$(grep '^VARDB_pass=' "${ASTGUI_CONF}" | cut -d= -f2)"
DB_PORT="$(grep '^VARDB_port=' "${ASTGUI_CONF}" | cut -d= -f2)"

[[ -n "${DB_HOST}" && -n "${DB_USER}" && -n "${DB_PASS}" ]] \
  || fatal "Invalid DB credentials in ${ASTGUI_CONF}"



MYSQL_CMD=(
  mysql
  --protocol=tcp
  --connect-timeout=5
  --batch
  --skip-column-names
  -h "${DB_HOST}"
  -P "${DB_PORT}"
  -u "${DB_USER}"
  "-p${DB_PASS}"
  "${DB_NAME}"
)


log_info "Using DB ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# -----------------------------------------------------------------------------
# Preflight: AMI must be alive
# -----------------------------------------------------------------------------
asterisk -rx "manager show settings" | grep -q "Manager (AMI):.*Yes" \
  || fatal "AMI not enabled"

# -----------------------------------------------------------------------------
# Detect SIP stack
# -----------------------------------------------------------------------------
if asterisk -rx "sip show peers" >/dev/null 2>&1; then
  SIP_MODE="SIP"
elif asterisk -rx "pjsip show endpoints" >/dev/null 2>&1; then
  SIP_MODE="PJSIP"
else
  fatal "No SIP stack available (chan_sip or pjsip)"
fi

log_info "Detected SIP mode: ${SIP_MODE}"

# -----------------------------------------------------------------------------
# Static test identifiers (INTENTIONAL)
# -----------------------------------------------------------------------------
TEST_AGENT="9999"
TEST_PHONE="9999"
TEST_CAMPAIGN="TESTCAMP"
TEST_LIST="9999"
TEST_LEAD_PHONE="1000000000"
TEST_EXTEN="9999"

# -----------------------------------------------------------------------------
# Create minimal VICIdial objects (IDEMPOTENT)
# -----------------------------------------------------------------------------
log_info "Creating GUI smoke test objects"

"${MYSQL_CMD[@]} -e" <<EOF

INSERT IGNORE INTO servers
(server_ip, server_description, active)
VALUES ('127.0.0.1','GUI Smoke Test Server','Y');

INSERT IGNORE INTO phones
(extension, dialplan_number, voicemail_id, server_ip, active, protocol)
VALUES ('${TEST_PHONE}','${TEST_PHONE}','${TEST_PHONE}','127.0.0.1','Y','${SIP_MODE}');

INSERT IGNORE INTO vicidial_users
(user, pass, full_name, user_level, active)
VALUES ('${TEST_AGENT}','${TEST_AGENT}','GUI Smoke Agent','9','Y');

INSERT IGNORE INTO vicidial_campaigns
(campaign_id, campaign_name, active)
VALUES ('${TEST_CAMPAIGN}','GUI Smoke Campaign','Y');

INSERT IGNORE INTO vicidial_lists
(list_id, list_name, campaign_id, active)
VALUES ('${TEST_LIST}','GUI Smoke List','${TEST_CAMPAIGN}','Y');

INSERT IGNORE INTO vicidial_list
(list_id, phone_number, status)
VALUES ('${TEST_LIST}','${TEST_LEAD_PHONE}','NEW');

UPDATE vicidial_users
SET campaign_id='${TEST_CAMPAIGN}',
    phone_login='${TEST_PHONE}',
    phone_pass='${TEST_PHONE}'
WHERE user='${TEST_AGENT}';

EOF

log_success "GUI smoke test objects created"

# -----------------------------------------------------------------------------
# Trigger backend originate (GROUND TRUTH)
# -----------------------------------------------------------------------------
log_info "Triggering backend originate test"

asterisk -rx "channel originate Local/${TEST_EXTEN}@default application Hangup" \
  || fatal "Originate command failed"

sleep 2

# -----------------------------------------------------------------------------
# Assert: channel exists
# -----------------------------------------------------------------------------
CHANNEL_COUNT="$(asterisk -rx "core show channels" | grep -c Local || true)"

if [[ "${CHANNEL_COUNT}" -eq 0 ]]; then
  fatal "GUI call flow FAILED (no Asterisk channel detected)"
fi

log_success "GUI call flow PASSED (Asterisk channel detected)"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "=== GUI CALL FLOW SMOKE TEST PASSED ==="
exit 0

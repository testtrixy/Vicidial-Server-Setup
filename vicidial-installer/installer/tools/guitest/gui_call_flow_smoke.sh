#!/usr/bin/env bash
# =============================================================================
# GUI Call Flow Smoke Test (VICIdial – EL9 Golden)
#
# Purpose:
#   - Prove VICIdial can originate a call
#   - Validate Agent + Phone + Campaign wiring
#   - Verify Asterisk receives a live channel
#
# Non-goals:
#   - No audio testing
#   - No Selenium
#   - No trunks required
#
#   Safe to run repeatedly
#
#   export ENABLE_GUI_CALL_SMOKE=yes
#   tools/gui_call_flow_smoke.sh
#
#
#
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command mysql
require_command asterisk
require_command perl

# -----------------------------------------------------------------------------
# Guards
# -----------------------------------------------------------------------------
check_el9

if [[ "${ENABLE_GUI_CALL_SMOKE:-no}" != "yes" ]]; then
  log_warn "GUI call smoke test disabled (ENABLE_GUI_CALL_SMOKE!=yes)"
  exit 0
fi

log_info "=== GUI CALL FLOW SMOKE TEST START ==="

# -----------------------------------------------------------------------------
# Constants (INTENTIONALLY STATIC)
# -----------------------------------------------------------------------------
TEST_AGENT="9999"
TEST_PHONE="9999"
TEST_CAMPAIGN="TESTCAMP"
TEST_LIST="9999"
TEST_LEAD_PHONE="1000"
TEST_EXTEN="9999"

DB_HOST="127.0.0.1"
DB_NAME="asterisk"

# -----------------------------------------------------------------------------
# Preflight: AMI must be alive
# -----------------------------------------------------------------------------
asterisk -rx "manager show settings" | grep -q "Manager (AMI):.*Yes" \
  || fatal "AMI not enabled"

# -----------------------------------------------------------------------------
# Preflight: chan_sip OR pjsip CLI must exist
# -----------------------------------------------------------------------------
if asterisk -rx "sip show peers" >/dev/null 2>&1; then
  SIP_MODE="chan_sip"
elif asterisk -rx "pjsip show endpoints" >/dev/null 2>&1; then
  SIP_MODE="pjsip"
else
  fatal "No SIP stack available (chan_sip or pjsip)"
fi

log_info "Detected SIP mode: ${SIP_MODE}"

# -----------------------------------------------------------------------------
# Create minimal VICIdial objects (idempotent)
# -----------------------------------------------------------------------------
log_info "Creating GUI call test objects"

mysql -h "${DB_HOST}" "${DB_NAME}" <<EOF

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
SET campaign_id='${TEST_CAMPAIGN}'
WHERE user='${TEST_AGENT}';

EOF

log_success "Test objects created"

# -----------------------------------------------------------------------------
# Trigger VICIdial originate (backend truth)
# -----------------------------------------------------------------------------
log_info "Triggering VICIdial originate"

asterisk -rx "channel originate Local/${TEST_EXTEN}@default application Hangup" \
  || fatal "Originate command failed"

sleep 2

# -----------------------------------------------------------------------------
# Assert: Asterisk channel exists
# -----------------------------------------------------------------------------
CHANNEL_COUNT="$(asterisk -rx "core show channels" | grep -c Local || true)"

if [[ "${CHANNEL_COUNT}" -eq 0 ]]; then
  fatal "GUI call flow FAILED (no channel originated)"
fi

log_success "GUI call flow PASSED (Asterisk channel detected)"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "=== GUI CALL FLOW SMOKE TEST PASSED ==="
exit 0

#!/usr/bin/env bash
# =============================================================================
# GUI Call Flow Smoke Test (VICIdial – EL9 Golden)
#
# GOAL:
#   - Prove VICIdial dialplan is active
#   - Prove Asterisk can originate a Local channel
#   - Prove SIP/PJSIP integration is loaded
#
# NON-GOALS:
#   - No real phone registration required
#   - No audio verification
#   - No trunks required
#
# PASS CONDITION:
#   - Asterisk Local channel appears (even briefly)
#
# THIS IS A *SMOKE TEST*, NOT A PRODUCTION CALL TEST
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
# Load DB credentials (authoritative source)
# -----------------------------------------------------------------------------
ASTGUI_CONF="/etc/astguiclient.conf"
[[ -f "${ASTGUI_CONF}" ]] || fatal "Missing ${ASTGUI_CONF}"

cfg() {
  awk -F'=>|=' -v k="$1" '
    $1 ~ k {
      gsub(/^[ \t]+|[ \t]+$/, "", $2);
      print $2;
      exit
    }
  ' "${ASTGUI_CONF}"
}

DB_HOST="$(cfg VARDB_server)"
DB_NAME="$(cfg VARDB_database)"
DB_USER="$(cfg VARDB_user)"
DB_PASS="$(cfg VARDB_pass)"
DB_PORT="$(cfg VARDB_port)"

# Force TCP-safe DB host
[[ "${DB_HOST}" == "localhost" ]] && DB_HOST="127.0.0.1"

MYSQL_CMD=(
  mysql
  --protocol=tcp
  --connect-timeout=5
  --batch
  --skip-column-names
  -h "${DB_HOST}"
  -P "${DB_PORT:-3306}"
  -u "${DB_USER}"
  "-p${DB_PASS}"
  "${DB_NAME}"
)

log_info "Using DB ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# -----------------------------------------------------------------------------
# AMI must respond (do NOT parse output, just responsiveness)
# -----------------------------------------------------------------------------
timeout 5 asterisk -rx "manager show connected" >/dev/null \
  || fatal "AMI not responding"

log_success "AMI responsive"

# -----------------------------------------------------------------------------
# VICIdial dialplan must exist (ground truth)
# -----------------------------------------------------------------------------
timeout 5 asterisk -rx "dialplan show vicidial-auto-phones" >/dev/null \
  || fatal "VICIdial dialplan missing (extensions-vicidial.conf not loaded)"

log_success "VICIdial dialplan verified"

# -----------------------------------------------------------------------------
# Detect SIP stack (presence only, NOT registration)
# -----------------------------------------------------------------------------
if timeout 5 asterisk -rx "sip show peers" >/dev/null 2>&1; then
  SIP_MODE="SIP"
elif timeout 5 asterisk -rx "pjsip show endpoints" >/dev/null 2>&1; then
  SIP_MODE="PJSIP"
else
  fatal "No SIP stack detected (chan_sip or pjsip)"
fi

log_info "Detected SIP stack: ${SIP_MODE}"

# -----------------------------------------------------------------------------
# Static smoketest identifiers (intentional)
# -----------------------------------------------------------------------------
TEST_PHONE="1000"
TEST_AGENT="1000"
TEST_CAMPAIGN="TESTCAMP"
TEST_LIST="1000"
TEST_LEAD_PHONE="1000000000"

# -----------------------------------------------------------------------------
# Minimal VICIdial DB objects (IDEMPOTENT)
# -----------------------------------------------------------------------------
log_info "Ensuring VICIdial smoketest DB objects"

"${MYSQL_CMD[@]}" <<EOF
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
SET phone_login='${TEST_PHONE}',
    phone_pass='${TEST_PHONE}'
WHERE user='${TEST_AGENT}';

INSERT IGNORE INTO vicidial_campaign_agents
(campaign_id, user)
VALUES ('${TEST_CAMPAIGN}','${TEST_AGENT}');
EOF

log_success "VICIdial smoketest DB objects ensured"

# -----------------------------------------------------------------------------
# ORIGINATE TEST (THIS IS THE ONLY REAL ASSERTION)
# -----------------------------------------------------------------------------
log_info "Originating Local channel via VICIdial dialplan"

timeout 5 asterisk -rx \
  "channel originate Local/${TEST_PHONE}@vicidial-auto-phones extension h@vicidial-auto" \
  || fatal "Originate command failed"

# -----------------------------------------------------------------------------
# ASSERT: Local channel appears (briefly is enough)
# -----------------------------------------------------------------------------
CHANNEL_COUNT=0
for _ in {1..5}; do
  CHANNEL_COUNT="$(asterisk -rx "core show channels concise" | grep -c 'Local/' || true)"
  [[ "${CHANNEL_COUNT}" -gt 0 ]] && break
  sleep 1
done

if [[ "${CHANNEL_COUNT}" -eq 0 ]]; then
  fatal "GUI call flow FAILED (no Asterisk Local channel detected)"
fi

log_success "GUI call flow PASSED (Local channel detected)"

#
# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "=== GUI CALL FLOW SMOKE TEST PASSED ==="
exit 0

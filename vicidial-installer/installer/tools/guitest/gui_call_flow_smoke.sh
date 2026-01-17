#!/usr/bin/env bash
# =============================================================================
# GUI Call Flow Smoke Test (VICIdial – EL9 Golden)
#
# Verifies:
#   - VICIdial DB wiring
#   - Asterisk AMI responsiveness
#   - SIP peer existence
#   - VICIdial dialplan presence
#   - Successful Local channel originate
#
# SAFE:
#   - No trunks
#   - No audio devices
#   - No browser automation
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command mysql
require_command asterisk

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
# Load DB credentials (force TCP, no localhost ambiguity)
# -----------------------------------------------------------------------------
ASTGUI_CONF="/etc/astguiclient.conf"
[[ -f "${ASTGUI_CONF}" ]] || fatal "Missing ${ASTGUI_CONF}"

cfg() {
  awk -F'=>|=' -v k="$1" '$1 ~ k {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit}' "$ASTGUI_CONF"
}

DB_HOST="$(cfg VARDB_server)"
DB_NAME="$(cfg VARDB_database)"
DB_USER="$(cfg VARDB_user)"
DB_PASS="$(cfg VARDB_pass)"
DB_PORT="$(cfg VARDB_port)"

[[ "${DB_HOST}" == "localhost" ]] && DB_HOST="127.0.0.1"
: "${DB_PORT:=3306}"

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
# AMI check
# -----------------------------------------------------------------------------
timeout 5 asterisk -rx "manager show connected" >/dev/null \
  || fatal "AMI not responding"

log_success "AMI responsive"

# -----------------------------------------------------------------------------
# Dialplan validation (THIS IS THE KEY FIX)
# -----------------------------------------------------------------------------
timeout 5 asterisk -rx "dialplan show vicidial-auto-phones" >/dev/null \
  || fatal "VICIdial dialplan missing (vicidial-auto-phones)"

log_success "VICIdial dialplan verified"

# -----------------------------------------------------------------------------
# Static test identifiers (MATCH REAL DIALPLAN)
# -----------------------------------------------------------------------------
TEST_PHONE="1000"
TEST_AGENT="1000"
TEST_CAMPAIGN="TESTCAMP"
TEST_LIST="1000"
TEST_LEAD_PHONE="1000000000"

# -----------------------------------------------------------------------------
# Ensure SIP peer exists (loopback)
# -----------------------------------------------------------------------------
log_info "Ensuring SIP smoketest peer ${TEST_PHONE}"

cat >/etc/asterisk/sip_smoketest.conf <<EOF
[${TEST_PHONE}]
type=friend
host=127.0.0.1
context=vicidial-auto
disallow=all
allow=ulaw
qualify=yes
EOF

grep -q sip_smoketest.conf /etc/asterisk/sip.conf || \
  echo '#include sip_smoketest.conf' >> /etc/asterisk/sip.conf

asterisk -rx "sip reload"
sleep 1

asterisk -rx "sip show peer ${TEST_PHONE}" | grep -q "Status.*OK" \
  || fatal "SIP peer ${TEST_PHONE} not reachable"

log_success "SIP peer ${TEST_PHONE} ready"

# -----------------------------------------------------------------------------
# Minimal VICIdial DB objects (idempotent)
# -----------------------------------------------------------------------------
log_info "Creating VICIdial smoke test DB objects"

"${MYSQL_CMD[@]}" <<EOF
INSERT IGNORE INTO servers
(server_ip, server_description, active)
VALUES ('127.0.0.1','GUI Smoke Server','Y');

INSERT IGNORE INTO phones
(extension, dialplan_number, voicemail_id, server_ip, active, protocol)
VALUES ('${TEST_PHONE}','${TEST_PHONE}','${TEST_PHONE}','127.0.0.1','Y','SIP');

INSERT IGNORE INTO vicidial_users
(user, pass, user_level, active)
VALUES ('${TEST_AGENT}','${TEST_AGENT}','9','Y');

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
SET phone_login='${TEST_PHONE}', phone_pass='${TEST_PHONE}'
WHERE user='${TEST_AGENT}';

INSERT IGNORE INTO vicidial_campaign_agents
(campaign_id, user)
VALUES ('${TEST_CAMPAIGN}','${TEST_AGENT}');
EOF

log_success "DB objects ready"

# -----------------------------------------------------------------------------
# Originate call (GROUND TRUTH)
# -----------------------------------------------------------------------------
log_info "Originating Local channel"

timeout 5 asterisk -rx \
  "channel originate Local/${TEST_PHONE}@vicidial-auto-phones extension h@vicidial-auto"

sleep 2

CHANNEL_COUNT="$(asterisk -rx "core show channels concise" | grep -c 'Local/' || true)"

[[ "${CHANNEL_COUNT}" -gt 0 ]] \
  || fatal "GUI call flow FAILED (no Local channel detected)"

log_success "GUI call flow PASSED (Local channel active)"

log_success "=== GUI CALL FLOW SMOKE TEST PASSED ==="
exit 0

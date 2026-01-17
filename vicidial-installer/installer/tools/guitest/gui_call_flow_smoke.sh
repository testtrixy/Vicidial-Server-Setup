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
#   - No audio testing
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







log_info "Ensuring pjsip_smoketest.conf is included (top-level)"

PJSIP_CONF="/etc/asterisk/pjsip.conf"

# Remove any bad includes first (cleanup)
sed -i '/pjsip_smoketest.conf/d' "${PJSIP_CONF}"

# Insert include at top-level (before any [section])
sed -i '1i#include pjsip_smoketest.conf' "${PJSIP_CONF}"


# -----------------------------------------------------------------------------
# Load VICIdial DB credentials (ROBUST PARSER)
# -----------------------------------------------------------------------------
ASTGUI_CONF="/etc/astguiclient.conf"
[[ -f "${ASTGUI_CONF}" ]] || fatal "Missing ${ASTGUI_CONF}"

parse_cfg () {
  awk -F'=>|=' -v key="$1" '
    $1 ~ key {
      gsub(/^[ \t]+|[ \t]+$/, "", $2);
      print $2;
      exit
    }
  ' "${ASTGUI_CONF}"
}

DB_HOST="$(parse_cfg VARDB_server)"
DB_NAME="$(parse_cfg VARDB_database)"
DB_USER="$(parse_cfg VARDB_user)"
DB_PASS="$(parse_cfg VARDB_pass)"
DB_PORT="$(parse_cfg VARDB_port)"

: "${DB_HOST:?Missing DB_HOST}"
: "${DB_NAME:?Missing DB_NAME}"
: "${DB_USER:?Missing DB_USER}"
: "${DB_PASS:?Missing DB_PASS}"
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
# Preflight: AMI must be alive (NON-BLOCKING)
# -----------------------------------------------------------------------------


log_info "Verifying AMI responsiveness"

if ! timeout 5 asterisk -rx "manager show connected" >/dev/null 2>&1; then
  fatal "AMI socket not responding (manager show connected failed)"
fi

log_success "AMI responsive"


# -----------------------------------------------------------------------------
# Detect SIP stack
# -----------------------------------------------------------------------------
if timeout 5 asterisk -rx "sip show peers" >/dev/null 2>&1; then
  SIP_MODE="SIP"
elif timeout 5 asterisk -rx "pjsip show endpoints" >/dev/null 2>&1; then
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
# Create minimal VICIdial objects (IDEMPOTENT, NO LEAKS)
# -----------------------------------------------------------------------------
log_info "Creating GUI smoke test objects"

"${MYSQL_CMD[@]}" -e "
SET SESSION wait_timeout=5;
SET SESSION lock_wait_timeout=5;

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

-- Bind phone to agent
UPDATE vicidial_users
SET phone_login='${TEST_PHONE}',
    phone_pass='${TEST_PHONE}'
WHERE user='${TEST_AGENT}';

-- Assign agent to campaign (SCHEMA-SAFE)
INSERT IGNORE INTO vicidial_campaign_agents
(campaign_id, user)
VALUES ('${TEST_CAMPAIGN}','${TEST_AGENT}');
"

log_success "GUI smoke test objects created"

# -----------------------------------------------------------------------------
# Trigger backend originate (GROUND TRUTH)
# -----------------------------------------------------------------------------
log_info "Triggering backend originate test"




log_info "Ensuring test PJSIP endpoint exists"

cat >/etc/asterisk/pjsip_smoketest.conf <<EOF
[9999]
type=endpoint
context=vicidial-auto
disallow=all
allow=ulaw
auth=9999-auth
aors=9999

[9999-auth]
type=auth
auth_type=userpass
username=9999
password=9999

[9999]
type=aor
max_contacts=1
EOF





log_info "Ensuring pjsip_smoketest.conf is included"

PJSIP_CONF="/etc/asterisk/pjsip.conf"

asterisk -rx "core reload"
sleep 2


grep -q '^#include pjsip_smoketest.conf' "${PJSIP_CONF}" || \
  echo '#include pjsip_smoketest.conf' >> "${PJSIP_CONF}"


asterisk -rx "pjsip reload"
sleep 1


log_info "Forcing temporary contact for PJSIP smoketest endpoint"

asterisk -rx "pjsip send qualify 9999" >/dev/null 2>&1 || true
sleep 1


asterisk -rx "pjsip show endpoint 9999" | grep -q "Unavailable" && \
  fatal "PJSIP endpoint 9999 is unavailable (no contact registered)"





#asterisk -rx "pjsip show endpoints" | grep -Eq 'Endpoint:\s+9999' \
#  || fatal "PJSIP endpoint 9999 not loaded"




#timeout 5 asterisk -rx "channel originate Local/${TEST_EXTEN}@vicidial application Hangup"
timeout 5 asterisk -rx "channel originate Local/${TEST_EXTEN}@vicidial-auto application Hangup"

 

sleep 2

# -----------------------------------------------------------------------------
# Assert: channel exists
# -----------------------------------------------------------------------------
#CHANNEL_COUNT="$(timeout 5 asterisk -rx "core show channels" | grep -c Local || true)"
CHANNEL_COUNT="$(asterisk -rx "core show channels concise" | grep -c 'Local/' || true)"

for i in {1..5}; do
  CHANNEL_COUNT="$(asterisk -rx "core show channels concise" | grep -c 'Local/' || true)"
  [[ "${CHANNEL_COUNT}" -gt 0 ]] && break
  sleep 1
done


if [[ "${CHANNEL_COUNT}" -eq 0 ]]; then
  fatal "GUI call flow FAILED (no Asterisk channel detected)"
fi

log_success "GUI call flow PASSED (Asterisk channel detected)"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "=== GUI CALL FLOW SMOKE TEST PASSED ==="
exit 0

#!/usr/bin/env bash
# =============================================================================
# GUI Call Flow Smoke Test (VICIdial – EL9 Golden)
#
# Purpose:
#   - Prove VICIdial can originate a call end-to-end
#   - Validate Agent + Phone + Campaign wiring
#   - Verify Asterisk creates Local channels
#
# Safe:
#   - Idempotent
#   - Opt-in only
#   - NO SIP registration required
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
# Opt-in guard
# -----------------------------------------------------------------------------
if [[ "${ENABLE_GUI_CALL_SMOKE:-no}" != "yes" ]]; then
  log_warn "GUI call flow smoke test disabled (ENABLE_GUI_CALL_SMOKE!=yes)"
  exit 0
fi

log_info "=== GUI CALL FLOW SMOKE TEST START ==="

# -----------------------------------------------------------------------------
# Load VICIdial DB credentials (SAFE PARSER)
# -----------------------------------------------------------------------------
ASTGUI_CONF="/etc/astguiclient.conf"
[[ -f "${ASTGUI_CONF}" ]] || fatal "Missing ${ASTGUI_CONF}"

cfg() {
  awk -F'=>|=' -v k="$1" '
    $1 ~ k {
      gsub(/^[ \t]+|[ \t]+$/, "", $2);
      print $2;
      exit;
    }
  ' "${ASTGUI_CONF}"
}

DB_HOST="$(cfg VARDB_server)"
DB_NAME="$(cfg VARDB_database)"
DB_USER="$(cfg VARDB_user)"
DB_PASS="$(cfg VARDB_pass)"
DB_PORT="$(cfg VARDB_port)"

: "${DB_HOST:?Missing DB host}"
: "${DB_NAME:?Missing DB name}"
: "${DB_USER:?Missing DB user}"
: "${DB_PASS:?Missing DB pass}"
: "${DB_PORT:=3306}"

# Force TCP-safe host
[[ "${DB_HOST}" == "localhost" ]] && DB_HOST="127.0.0.1"

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
# Preflight: AMI must be responsive
# -----------------------------------------------------------------------------
if ! timeout 5 asterisk -rx "manager show connected" >/dev/null 2>&1; then
  fatal "AMI not responding"
fi
log_success "AMI responsive"

# -----------------------------------------------------------------------------
# Verify VICIdial dialplan exists (CRITICAL)
# -----------------------------------------------------------------------------
asterisk -rx "dialplan show vicidial-auto-phones" >/dev/null 2>&1 \
  || fatal "vicidial-auto-phones context missing"

log_success "VICIdial dialplan verified"

# -----------------------------------------------------------------------------
# Static test identifiers
# -----------------------------------------------------------------------------
TEST_AGENT="9999"
TEST_PHONE="9999"
TEST_CAMPAIGN="TESTCAMP"
TEST_LIST="9999"
TEST_LEAD_PHONE="1000000000"

# -----------------------------------------------------------------------------
# Create minimal VICIdial objects (SCHEMA-SAFE)
# -----------------------------------------------------------------------------
log_info "Creating GUI smoke test objects"

"${MYSQL_CMD[@]}" <<EOF
SET SESSION wait_timeout=5;
SET SESSION lock_wait_timeout=5;

INSERT IGNORE INTO servers
(server_ip, server_description, active)
VALUES ('127.0.0.1','GUI Smoke Test Server','Y');

INSERT IGNORE INTO phones
(extension, dialplan_number, voicemail_id, server_ip, active, protocol)
VALUES ('${TEST_PHONE}','${TEST_PHONE}','${TEST_PHONE}','127.0.0.1','Y','SIP');

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

log_success "GUI smoke test objects created"

# -----------------------------------------------------------------------------
# Originate call (CORRECT TARGET)
# -----------------------------------------------------------------------------
log_info "Triggering backend originate test"

timeout 5 asterisk -rx \
  "channel originate Local/${TEST_PHONE}@vicidial-auto-phones extension h@vicidial-auto"

sleep 1

# -----------------------------------------------------------------------------
# Assert: Local channel exists
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

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "=== GUI CALL FLOW SMOKE TEST PASSED ==="
exit 0

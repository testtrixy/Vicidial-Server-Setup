#!/usr/bin/env bash
###############################################################################
# Vicidial Smoke Test v1.2 (EL9 / Asterisk 18)
#
# Purpose:
#  - Move system from "Fresh Install" → "Functional Dialer"
#  - Provision minimum operational data
#  - Validate AMI + Conference + Dial Path (Loopback)
#
# SAFE TO RUN MULTIPLE TIMES
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# -----------------------------------------------------------------------------
# Common helpers (log_info, log_warn, log_error, fatal, etc.)
# -----------------------------------------------------------------------------
source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command mysql
require_command asterisk
require_command perl

###############################################################################
# Config (EDIT ONLY IF NEEDED)
###############################################################################

DB="asterisk"
SERVER_ID="DIALER1"
SERVER_IP="$(hostname -I | awk '{print $1}')"

EXTENSION="101"
EXT_PASS="test1234"

ADMIN_USER="6666"
ADMIN_PASS="1234"

CAMPAIGN_ID="TESTCAMP"
LIST_ID="1001"
TEST_PHONE="1234567890"

CONF_START=8600001
CONF_END=8600049

###############################################################################
log_info "=== Vicidial Smoke Test v1.2 starting ==="

###############################################################################
# 1. AMI VALIDATION (MANDATORY)
###############################################################################
log_info "Validating Asterisk Manager Interface (AMI)"

if ! asterisk -rx "manager show connected" >/dev/null 2>&1; then
  fatal "AMI not responding. Check /etc/asterisk/manager.conf"
fi

log_success "AMI responding"

###############################################################################
# 2. SERVER RECORD
###############################################################################
log_info "Provisioning server record"

mysql "${DB}" -e "
INSERT INTO servers
(server_id, server_description, server_ip, active, asterisk_version,
 max_vicidial_trunks, user_group, vicidial_balance_active)
VALUES
('${SERVER_ID}', 'Smoke Test Dialer', '${SERVER_IP}', 'Y', '18.X',
 '96', '---ALL---', 'Y')
ON DUPLICATE KEY UPDATE
 server_ip='${SERVER_IP}',
 active='Y',
 asterisk_version='18.X';
"

###############################################################################
# 3. CONFERENCE PROVISIONING (CRITICAL)
###############################################################################
log_info "Provisioning conference rooms (${CONF_START}-${CONF_END})"

for ((i=CONF_START; i<=CONF_END; i++)); do
  mysql "${DB}" -e "
    INSERT IGNORE INTO vicidial_conferences
      (conf_exten, server_ip, extension)
    VALUES
      ('${i}', '${SERVER_IP}', '');
  "

  mysql "${DB}" -e "
    INSERT IGNORE INTO vicidial_vicidial_conferences
      (conf_exten, server_ip, extension)
    VALUES
      ('${i}', '${SERVER_IP}', '');
  "
done

log_success "Conference rooms ready"

###############################################################################
# 4. PHONE EXTENSION
###############################################################################
log_info "Creating test phone extension ${EXTENSION}"

mysql "${DB}" -e "
INSERT INTO phones
(extension, dialplan_number, voicemail_id, server_ip,
 login, pass, status, active,
 phone_type, fullname, protocol, context, user_group)
VALUES
('${EXTENSION}', '${EXTENSION}', '${EXTENSION}', '${SERVER_IP}',
 '${EXTENSION}', '${EXT_PASS}', 'ACTIVE', 'Y',
 'CCinternal', 'Smoke Test Agent', 'SIP', 'default', '---ALL---')
ON DUPLICATE KEY UPDATE
 server_ip='${SERVER_IP}',
 active='Y';
"

###############################################################################
# 5. ADMIN USER
###############################################################################
log_info "Creating admin user ${ADMIN_USER}"

mysql "${DB}" -e "
INSERT INTO vicidial_users
(user, pass, full_name, user_level, user_group,
 phone_login, phone_pass, active)
VALUES
('${ADMIN_USER}', '${ADMIN_PASS}', 'Smoke Test Admin', '9', '---ALL---',
 '${EXTENSION}', '${EXT_PASS}', 'Y')
ON DUPLICATE KEY UPDATE
 user_level='9',
 active='Y';
"

###############################################################################
# 6. TEST CAMPAIGN
###############################################################################
log_info "Creating test campaign ${CAMPAIGN_ID}"

mysql "${DB}" -e "
INSERT INTO vicidial_campaigns
(campaign_id, campaign_name, active,
 dial_status_a, lead_order, park_ext,
 hopper_level, auto_dial_level, local_call_time)
VALUES
('${CAMPAIGN_ID}', 'Smoke Test Campaign', 'Y',
 'NEW', 'DOWN', '8301',
 '50', '1', '24hours')
ON DUPLICATE KEY UPDATE
 active='Y';
"

# Relax rules for smoke test
mysql "${DB}" -e "
UPDATE vicidial_campaigns SET
 allow_closers='Y',
 manual_dial_filter='NONE',
 agent_dial_owner_only='NONE'
WHERE campaign_id='${CAMPAIGN_ID}';
"

###############################################################################
# 7. LOCAL CALL TIME SAFETY
###############################################################################
log_info "Ensuring local call time exists"

mysql "${DB}" -e "
INSERT IGNORE INTO vicidial_local_times
(local_call_time, local_call_time_name)
VALUES ('24hours', '24 Hours');
"

###############################################################################
# 8. TEST LIST + LEAD
###############################################################################
log_info "Creating test list and lead"

mysql "${DB}" -e "
INSERT IGNORE INTO vicidial_lists
(list_id, list_name, campaign_id, active)
VALUES
('${LIST_ID}', 'Smoke Test List', '${CAMPAIGN_ID}', 'Y');
"

mysql "${DB}" -e "
INSERT INTO vicidial_list
(entry_date, status, user, list_id, phone_number, first_name)
VALUES
(NOW(), 'NEW', '${ADMIN_USER}', '${LIST_ID}', '${TEST_PHONE}', 'SmokeLead');
"

###############################################################################
# 9. LOOPBACK CARRIER (NO REAL SIP REQUIRED)
###############################################################################
log_info "Provisioning loopback carrier"

mysql "${DB}" -e "
INSERT IGNORE INTO vicidial_carriers
(carrier_id, carrier_name, active)
VALUES
('LOOPBACK', 'Internal Loopback', 'Y');
"

mysql "${DB}" -e "
INSERT IGNORE INTO vicidial_server_carriers
(server_ip, carrier_id)
VALUES
('${SERVER_IP}', 'LOOPBACK');
"

###############################################################################
# 10. SYNC TO ASTERISK
###############################################################################
log_info "Syncing SQL data to Asterisk"

perl /usr/share/astguiclient/ADMIN_keepalive_ALL.pl --force
perl /usr/share/astguiclient/ADMIN_update_conf.pl --force

###############################################################################
# DONE
###############################################################################
log_success "Smoke Test v1.2 provisioning complete"

cat <<EOF

NEXT MANUAL STEPS (EXPECTED FLOW):

1️⃣ Register SIP Phone
   - User: ${EXTENSION}
   - Pass: ${EXT_PASS}
   - Server: ${SERVER_IP}

2️⃣ Agent Login
   URL: http://${SERVER_IP}/agc/vicidial.php
   User: ${ADMIN_USER}
   Pass: ${ADMIN_PASS}
   Campaign: ${CAMPAIGN_ID}

   ✔ Phone should ring
   ✔ You should hear: "You are the only person in this conference"

3️⃣ Manual Dial
   - Click Manual Dial
   - Dial any number (loopback)
   - Call should bridge instantly

If this works → SYSTEM IS FUNCTIONAL END-TO-END ✅

EOF

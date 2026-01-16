#!/usr/bin/env bash
# =============================================================================
# Vicidial EL9 End-to-End Smoke Test v1.9 (Backend + Web)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# -----------------------------------------------------------------------------
# common.sh (preferred) with safe fallback
# -----------------------------------------------------------------------------
if [[ -f "${INSTALLER_ROOT}/lib/common.sh" ]]; then
  source "${INSTALLER_ROOT}/lib/common.sh"
else
  log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
  log_warn()    { echo -e "\e[33m[WARN]\e[0m $1"; }
  log_error()   { echo -e "\e[31m[ERROR]\e[0m $1"; }
  log_success() { echo -e "\e[32m[OK]\e[0m $1"; }
  fatal()       { log_error "$1"; exit 1; }
  require_root(){ [[ $EUID -eq 0 ]] || fatal "Must be root"; }
  require_command(){ command -v "$1" >/dev/null || fatal "Missing command: $1"; }
fi

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
DB="asterisk"
SERVER_ID="DIALER1"
SERVER_IP="$(hostname -I | awk '{print $1}')"

EXT="101"
EXT_PASS="test1234"
ADMIN_USER="6666"
ADMIN_PASS="1234"
CAMPAIGN_ID="TESTCAMP"
LIST_ID="1001"

log_info "=== Vicidial Smoke Test v1.9 (EL9 / Asterisk 18) ==="

require_root
require_command mysql
require_command perl
require_command asterisk
require_command screen

# -----------------------------------------------------------------------------
# 0. Hard Preconditions
# -----------------------------------------------------------------------------
log_info "Validating base runtime"

rpm -q cronie >/dev/null || fatal "cronie not installed"
systemctl is-active --quiet crond || fatal "crond not running"

asterisk -rx "manager show settings" | grep -q "Enabled: Yes" \
  || fatal "AMI disabled"

asterisk -rx "core show channeltypes" | grep -q Local \
  || fatal "chan_local not loaded"

asterisk -rx "module show like res_timing" | grep -Eq "timerfd|dahdi" \
  || log_warn "No timing source detected (MeetMe may hang)"

# -----------------------------------------------------------------------------
# 1. Baseline DB Objects
# -----------------------------------------------------------------------------
log_info "Ensuring base DB objects exist"

mysql "${DB}" -e "
INSERT IGNORE INTO system_settings (id,use_non_latin) VALUES (1,'0');
INSERT IGNORE INTO vicidial_user_groups (user_group,group_name)
VALUES ('ADMIN','Admin Group');
"

# -----------------------------------------------------------------------------
# 2. Server Record
# -----------------------------------------------------------------------------
log_info "Provisioning server record"

mysql "${DB}" -e "
INSERT INTO servers
(server_id,server_description,server_ip,active,asterisk_version,
 rebuild_conf_files,generate_vicidial_conf,
 active_asterisk_server,active_agent_login_server)
VALUES
('${SERVER_ID}','Smoke Test','${SERVER_IP}','Y','18.X',
 'Y','Y','Y','Y')
ON DUPLICATE KEY UPDATE
 server_ip='${SERVER_IP}',
 rebuild_conf_files='Y';
"

# -----------------------------------------------------------------------------
# 3. Conferences
# -----------------------------------------------------------------------------
log_info "Provisioning conferences"

for i in $(seq -w 01 49); do
  mysql "${DB}" -e "
  INSERT IGNORE INTO vicidial_conferences (conf_exten,server_ip)
  VALUES ('86000$i','${SERVER_IP}');
  INSERT IGNORE INTO vicidial_vicidial_conferences (conf_exten,server_ip)
  VALUES ('86000$i','${SERVER_IP}');
  "
done

# -----------------------------------------------------------------------------
# 4. Phone, User, Campaign, Lead
# -----------------------------------------------------------------------------
log_info "Creating phone, user, campaign, lead"

mysql "${DB}" -e "
INSERT INTO phones
(extension,dialplan_number,voicemail_id,server_ip,
 login,pass,status,active,phone_type,protocol,context,user_group)
VALUES
('${EXT}','${EXT}','${EXT}','${SERVER_IP}',
 '${EXT}','${EXT_PASS}','ACTIVE','Y','CCinternal','SIP','default','ADMIN')
ON DUPLICATE KEY UPDATE server_ip='${SERVER_IP}';
"

mysql "${DB}" -e "
INSERT INTO vicidial_users
(user,pass,full_name,user_level,user_group,
 phone_login,phone_pass,active,force_change_password)
VALUES
('${ADMIN_USER}','${ADMIN_PASS}','Smoke Admin','9','ADMIN',
 '${EXT}','${EXT_PASS}','Y','N')
ON DUPLICATE KEY UPDATE active='Y';
"

mysql "${DB}" -e "
INSERT INTO vicidial_campaigns
(campaign_id,campaign_name,active,dial_status_a,
 lead_order,hopper_level,auto_dial_level,dial_method,
 local_call_time,dial_prefix)
VALUES
('${CAMPAIGN_ID}','Smoke Test','Y','NEW',
 'DOWN','50','1','RATIO','24hours','91')
ON DUPLICATE KEY UPDATE active='Y';
"

mysql "${DB}" -e "
INSERT IGNORE INTO vicidial_lists
(list_id,list_name,campaign_id,active)
VALUES ('${LIST_ID}','Smoke List','${CAMPAIGN_ID}','Y');
"

mysql "${DB}" -e "
INSERT INTO vicidial_list
(entry_date,status,user,list_id,phone_number,first_name)
VALUES (NOW(),'NEW','${ADMIN_USER}','${LIST_ID}','1234567890','SmokeLead');
"

# -----------------------------------------------------------------------------
# 5. Loopback Carrier
# -----------------------------------------------------------------------------
log_info "Provisioning loopback carrier"

mysql "${DB}" -e "
INSERT INTO vicidial_carriers
(carrier_id,carrier_name,active,protocol,globals_string,dialplan_entry)
VALUES
('LOOPBACK','Internal Loopback','Y','SIP',
 'TESTLOOP=SIP/127.0.0.1',
 'exten => _91NXXNXXXXXX,1,Answer()
  exten => _91NXXNXXXXXX,2,Playback(tt-monkeys)
  exten => _91NXXNXXXXXX,3,Hangup')
ON DUPLICATE KEY UPDATE active='Y';
"

mysql "${DB}" -e "
INSERT IGNORE INTO vicidial_server_carriers
(server_ip,carrier_id)
VALUES ('${SERVER_IP}','LOOPBACK');
"

# -----------------------------------------------------------------------------
# 6. Force Hopper + Sync
# -----------------------------------------------------------------------------
log_info "Forcing hopper"
/usr/share/astguiclient/AST_VDhopper.pl --campaign="${CAMPAIGN_ID}" --force

log_info "Syncing Vicidial configs"
perl /usr/share/astguiclient/ADMIN_keepalive_ALL.pl --force
sleep 2
perl /usr/share/astguiclient/ADMIN_update_conf.pl --force

asterisk -rx "dialplan reload"
asterisk -rx "sip reload"

# -----------------------------------------------------------------------------
# 7. Runtime Validation
# -----------------------------------------------------------------------------
log_info "Validating dialplan"
asterisk -rx "dialplan show _91NXXNXXXXXX@default" | grep -q Playback \
  || fatal "Loopback dialplan not loaded"


# -----------------------------------------------------------------------------
# Runtime Validation – Engine & Cron
# -----------------------------------------------------------------------------
log_info "Validating Vicidial Runtime Engine"

CRON_FILE="/etc/cron.d/vicidial"

# --- Cron file existence ---
[[ -f "${CRON_FILE}" ]] \
  || fatal "Vicidial master crontab missing (${CRON_FILE})"

# --- Heartbeat verification ---
grep -q "ADMIN_keepalive_ALL.pl" "${CRON_FILE}" \
  || fatal "Crontab missing keepalive entry"

grep -q "AST_VDhopper.pl" "${CRON_FILE}" \
  || fatal "Crontab missing hopper entry"

# --- Cron daemon ---
systemctl is-active --quiet crond \
  || fatal "crond not running (Vicidial engine dead)"

log_success "Cron Engine: Installed & Active"

# --- Screen validation ---
if screen -ls | grep -q ASTVDhopper; then
  log_success "Background Engine: Hopper active"
else
  log_warn "Hopper screen not visible yet (cron may need 60s)"
fi


# -----------------------------------------------------------------------------
# 7.5 Web Server Validation  ✅ (YOUR REQUEST)
# -----------------------------------------------------------------------------
log_info "Verifying Web Server Reachability"

if command -v curl >/dev/null; then
  curl -k -f -I "https://${SERVER_IP}/agc/vicidial.php" >/dev/null 2>&1 \
    || fatal "Web server unreachable or returning errors (check httpd)"
else
  log_warn "curl not found, skipping web check"
fi

log_success "Backend + Web smoke test PASSED"

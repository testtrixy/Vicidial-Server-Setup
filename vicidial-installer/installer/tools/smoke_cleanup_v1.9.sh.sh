#!/usr/bin/env bash
# ==============================================================
# VICIdial Smoke Cleanup v2.0 (EL9 Hardened)
# Purpose:
#  - Safely remove ONLY smoke-test artifacts
#  - Use MariaDB TCP access (127.0.0.1)
#  - Be tolerant of partial / failed smoke runs
#  - Never undo installer hardening (AMI, SIP, PJSIP)
# ==============================================================

# Cleanup must NEVER abort the pipeline
set +e

# -------------------------
# Logging helpers
# -------------------------
log_info()  { echo -e "[INFO]  $*"; }
log_warn()  { echo -e "[WARN]  $*"; }

# -------------------------
# Global vars
# -------------------------
DB="asterisk"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
SERVER_IP="$(hostname -I | awk '{print $1}')"

# -------------------------
# MySQL helper (TCP only)
# -------------------------
mysql_cmd() {
  mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" "$@"
}

log_info "Starting VICIdial Smoke Cleanup v2.0"
log_info "Target server IP: ${SERVER_IP}"

# -------------------------
# Database cleanup
# -------------------------
log_info "Cleaning VICIdial smoke-test database artifacts"

mysql_cmd "${DB}" <<EOF
DELETE FROM vicidial_conferences
  WHERE server_ip='${SERVER_IP}';

DELETE FROM vicidial_vicidial_conferences
  WHERE server_ip='${SERVER_IP}';

DELETE FROM vicidial_server_carriers
  WHERE server_ip='${SERVER_IP}';

DELETE FROM vicidial_carriers
  WHERE carrier_id='LOOPBACK';

DELETE FROM vicidial_list
  WHERE list_id='1001';

DELETE FROM vicidial_lists
  WHERE list_id='1001';

DELETE FROM vicidial_campaigns
  WHERE campaign_id='TESTCAMP';

DELETE FROM vicidial_users
  WHERE user='6666';

-- Safety guard: only delete smoke-test phones on THIS server
DELETE FROM phones
  WHERE extension='101'
    AND server_ip='${SERVER_IP}';

DELETE FROM servers
  WHERE server_ip='${SERVER_IP}'
    AND server_description='Smoke Test';
EOF

# -------------------------
# Post-cleanup verification (best-effort)
# -------------------------
log_info "Verifying cleanup results (best-effort)"

mysql_cmd "${DB}" -e "SELECT COUNT(*) AS remaining_smoke_campaigns FROM vicidial_campaigns WHERE campaign_id='TESTCAMP';" 2>/dev/null
mysql_cmd "${DB}" -e "SELECT COUNT(*) AS remaining_smoke_phones FROM phones WHERE extension='101' AND server_ip='${SERVER_IP}';" 2>/dev/null

# -------------------------
# Explicit non-actions (documentation)
# -------------------------
log_warn "Cleanup does NOT modify:"
log_warn " - Asterisk modules (chan_sip / chan_pjsip)"
log_warn " - AMI configuration"
log_warn " - astguiclient.conf"
log_warn " - System services"

log_info "Smoke cleanup completed (v2.0 harden
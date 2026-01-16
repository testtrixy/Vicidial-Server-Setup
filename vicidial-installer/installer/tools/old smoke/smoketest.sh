#!/usr/bin/env bash
# =============================================================================
# Vicidial Smoke Test – v1.2 (EL9)
#
# Purpose:
#   End-to-end functional validation:
#     DB → AMI → Conference → SIP → Agent → Campaign → Lead
#
# WARNING:
#   - DO NOT RUN ON PRODUCTION SYSTEMS
#   - COMMISSIONING / VALIDATION ONLY
#
# Compatible:
#   - Vicidial 2.14.x
#   - Asterisk 18
#   - MariaDB 10.11
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Resolve paths
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# -----------------------------------------------------------------------------
# Load shared helpers
# -----------------------------------------------------------------------------
source "${INSTALLER_ROOT}/lib/common.sh"

# -----------------------------------------------------------------------------
# Safety checks
# -----------------------------------------------------------------------------
require_root
require_command mysql
require_command asterisk

log_warn "VICIDIAL SMOKE TEST SCRIPT v1.2"
log_warn "THIS WILL INSERT TEST DATA INTO THE DATABASE"
log_warn "DO NOT RUN ON PRODUCTION SYSTEMS"

echo
read -p "Type YES to continue: " CONFIRM
[[ "${CONFIRM}" == "YES" ]] || fatal "Aborted by user"

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
DB_NAME="asterisk"

SERVER_ID="DIALER1"
SERVER_IP="$(hostname -I | awk '{print $1}')"

EXTENSION="101"
EXT_PASS="test1234"

ADMIN_USER="6666"
ADMIN_PASS="1234"

CAMPAIGN_ID="TESTCAMP"
LIST_ID="1001"

TEST_PHONE="1234567890"

log_info "Using server IP: ${SERVER_IP}"

# -----------------------------------------------------------------------------
# 0. Assert local call time exists
# -----------------------------------------------------------------------------
log_info "Validating local call time (24hours)"

mysql "${DB_NAME}" -e \
"SELECT local_call_time FROM vicidial_local_times WHERE local_call_time='24hours';" \
| grep -q 24hours || fatal "Missing local_call_time '24hours'"

# -----------------------------------------------------------------------------
# 1. Server record (UPSERT, non-destructive)
# -----------------------------------------------------------------------------
log_info "Provisioning server record"

mysql "${DB_NAME}" <<SQL
INSERT INTO servers (
  server_id,
  server_ip,
  server_description,
  active,
  active_asterisk_server,
  generate_vicidial_conf,
  rebuild_conf_files,
  asterisk_version
) VALUES (
  '${SERVER_ID}',
  '${SERVER_IP}',
  'Smoke Test Dialer',
  'Y',
  'Y',
  'Y',
  'Y',
  '18.X'
)
ON DUPLICATE KEY UPDATE
  active='Y',
  active_asterisk_server='Y',
  asterisk_version='18.X';
SQL

# -----------------------------------------------------------------------------
# 1.5 Conference provisioning (MANDATORY)
# -----------------------------------------------------------------------------
log_info "Provisioning MeetMe conference rooms (860001–860030)"

for i in $(seq -w 1 30); do
  mysql "${DB_NAME}" <<SQL
INSERT IGNORE INTO vicidial_conferences
(conf_exten, server_ip, extension)
VALUES ('86000${i}', '${SERVER_IP}', '');

INSERT IGNORE INTO vicidial_vicidial_conferences
(conf_exten, server_ip, extension)
VALUES ('86000${i}', '${SERVER_IP}', '');
SQL
done

# -----------------------------------------------------------------------------
# 2. Phone extension
# -----------------------------------------------------------------------------
log_info "Creating test phone extension (${EXTENSION})"

mysql "${DB_NAME}" <<SQL
INSERT INTO phones (
  extension,
  dialplan_numb_

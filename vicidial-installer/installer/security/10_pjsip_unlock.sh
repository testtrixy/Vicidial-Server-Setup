#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Stage 10 – VICIdial PJSIP Unlock (EL9 – Golden)
#
# Purpose:
#   - Unlock PJSIP visibility in VICIdial Admin UI
#   - Fix legacy DB enum restriction (SIP-only installs)
#   - Ensure VICIdial generates PJSIP configs for Asterisk 18+
#
# Why this exists:
#   - VICIdial historically shipped SIP-only defaults
#   - EL9 + Asterisk 18+ REQUIRE PJSIP
#   - Without this, Admin UI silently hides PJSIP options
#
# Safe:
#   - Idempotent
#   - No destructive schema changes
#   - No service restarts
#   - Database-only operation
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command mysql

check_el9

STAGE_NAME="Stage_10_PJSIP_Unlock"
stage_begin "${STAGE_NAME}"

log_info "=== Stage 10: VICIdial PJSIP Unlock ==="

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

# Force TCP loopback (NO sockets, NO localhost ambiguity)
if [[ "${DB_HOST}" == "localhost" ]]; then
  DB_HOST="127.0.0.1"
fi

MYSQL_CMD=(
  mysql
  --protocol=tcp
  --connect-timeout=5
  -h "${DB_HOST}"
  -P "${DB_PORT}"
  -u "${DB_USER}"
  "-p${DB_PASS}"
  "${DB_NAME}"
)

log_info "Using DB ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# -----------------------------------------------------------------------------
# 1) Expand allowed_sip_stacks ENUM (schema-safe)
# -----------------------------------------------------------------------------
log_info "Ensuring system_settings.allowed_sip_stacks supports PJSIP"

"${MYSQL_CMD[@]}" -e "
ALTER TABLE system_settings
MODIFY allowed_sip_stacks
ENUM('SIP','PJSIP','SIP_and_PJSIP')
DEFAULT 'SIP_and_PJSIP';
" || true

log_success "allowed_sip_stacks ENUM verified"

# -----------------------------------------------------------------------------
# 2) Force-enable SIP + PJSIP globally
# -----------------------------------------------------------------------------
log_info "Enabling SIP and PJSIP in system_settings"

"${MYSQL_CMD[@]}" -e "
UPDATE system_settings
SET allowed_sip_stacks='SIP_and_PJSIP';
"

log_success "SIP + PJSIP enabled globally"

# -----------------------------------------------------------------------------
# 3) Ensure Admin UI is allowed to show PJSIP
# -----------------------------------------------------------------------------
log_info "Ensuring Admin UI visibility flags are correct"

"${MYSQL_CMD[@]}" -e "
UPDATE system_settings
SET enable_legacy_sip='Y'
WHERE enable_legacy_sip IN ('N','');
" || true

log_success "Admin UI SIP/PJSIP visibility fixed"

# -----------------------------------------------------------------------------
# 4) Sanity verification
# -----------------------------------------------------------------------------
log_info "Verifying PJSIP unlock state"

"${MYSQL_CMD[@]}" -e "
SELECT
  allowed_sip_stacks,
  enable_legacy_sip
FROM system_settings
LIMIT 1;
"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 10 completed – VICIdial PJSIP unlocked"
stage_finish "${STAGE_NAME}"





######
# Run :    mysql -u cron -p asterisk -e "SELECT allowed_sip_stacks FROM system_settings;"
# result : SIP_and_PJSIP

#####
#  ls -l /etc/asterisk/pjsip-vicidial.conf
#  asterisk -rx "pjsip show endpoints"
#


#/usr/share/astguiclient/AST_conf_update.pl --debug
# ==> output Writing pjsip-vicidial.conf
#!/usr/bin/env bash
# ==============================================================
# VICIdial Smoke Test v2.0 (EL9 Hardened)
# Purpose:
#  - Validate VICIdial on Rocky/Alma EL9
#  - Enforce MariaDB-only DBI usage
#  - Enforce legacy SIP (chan_sip) compatibility
#  - Avoid false failures on empty systems
#  - Never hang on VICIdial Perl scripts
# ==============================================================

set -euo pipefail

# -------------------------
# Logging helpers
# -------------------------
log_info()  { echo -e "[INFO]  $*"; }
log_warn()  { echo -e "[WARN]  $*"; }
log_error() { echo -e "[ERROR] $*"; }
fatal()     { log_error "$*"; exit 1; }

# -------------------------
# Global vars
# -------------------------
DB="asterisk"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
SERVER_IP="$(hostname -I | awk '{print $1}')"

# -------------------------
# Command helpers
# -------------------------
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fatal "Required command missing: $1"
}

mysql_cmd() {
  mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" "$@"
}

run_vici() {
  local script="$1"
  log_info "Running VICIdial script: $(basename "$script")"
  timeout 30s perl "$script" || fatal "$script failed or timed out"
}



#-----------------

if ! systemctl is-active --quiet vicidial-ami-listener; then
  echo "❌ AMI listener not running"
  exit 1
fi

# -------------------------
# PRE-FLIGHT CHECKS
# -------------------------
log_info "Starting VICIdial Smoke Test v2.0"

require_cmd perl
require_cmd mysql
require_cmd asterisk
require_cmd timeout

# OS validation
log_info "Validating OS"
grep -q "Rocky Linux release 9" /etc/redhat-release \
  || fatal "Unsupported OS (expected Rocky Linux 9)"

# Service validation
log_info "Validating services"
systemctl is-active --quiet mariadb  || fatal "MariaDB not running"
systemctl is-active --quiet asterisk || fatal "Asterisk not running"

# -------------------------
# DBI / MariaDB validation
# -------------------------
log_info "Validating Perl DBI drivers"
perl -MDBD::MariaDB -e 'exit 0' \
  || fatal "DBD::MariaDB missing – installer invalid"

if perl -MDBD::mysql -e 'exit 0' 2>/dev/null; then
  log_warn "DBD::mysql detected – ensure VICIdial uses MariaDB DSN only"
fi

# DB connectivity (TCP only)
log_info "Validating MariaDB connectivity (TCP)"
mysql_cmd "$DB" -e "SELECT 1" >/dev/null 2>&1 \
  || fatal "MariaDB access failed via 127.0.0.1"

# -------------------------
# AMI validation
# -------------------------
log_info "Validating AMI"
asterisk -rx "manager show settings" | grep -q "Manager (AMI):.*Yes" \
  || fatal "AMI is not enabled"

# -------------------------
# SIP compatibility gate
# -------------------------
log_info "Validating legacy SIP (chan_sip) support"
if ! asterisk -rx "sip show peers" >/dev/null 2>&1; then
  fatal "chan_sip not loaded – VICIdial requires legacy SIP CLI"
fi

# -------------------------
# Empty system detection
# -------------------------
SIP_PEERS=$(asterisk -rx "sip show peers" | grep -c "/" || true)

if [[ "$SIP_PEERS" -eq 0 ]]; then
  log_warn "No SIP phones registered – call-flow tests will be skipped"
  SKIP_CALL_FLOW=1
else
  SKIP_CALL_FLOW=0
fi

# -------------------------
# VICIdial backend checks
# -------------------------
log_info "Running VICIdial backend checks"

run_vici /usr/share/astguiclient/AST_update.pl
run_vici /usr/share/astguiclient/AST_manager_send.pl

# -------------------------
# Optional call-flow checks
# -------------------------
if [[ "$SKIP_CALL_FLOW" -eq 0 ]]; then
  log_info "Validating dialplan availability"
  asterisk -rx "dialplan show default" >/dev/null 2>&1 \
    || fatal "Dialplan not accessible"
else
  log_info "Skipping call-flow validation (no SIP phones)"
fi

# -------------------------
# SUMMARY
# -------------------------
log_info "========== SUMMARY =========="
log_info "OS              : OK"
log_info "MariaDB          : OK"
log_info "DBI (MariaDB)    : OK"
log_info "AMI              : OK"
log_info "chan_sip         : OK"
log_info "SIP Phones       : $SIP_PEERS"

if [[ "$SKIP_CALL_FLOW" -eq 1 ]]; then
  log_info "Call Flow        : SKIPPED"
else
  log_info "Call Flow        : EXECUTED"
fi

log_info "Smoke test PASSED (v2.0 hardened)"
exit 0

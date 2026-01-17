#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Security Smoke Test – VICIdial EL9
#
# Purpose:
#   - Verify Fail2Ban + Firewall + Logs are protecting Asterisk
#   - Catch silent failures (regex not matching, jail disabled, etc.)
#
# Safe:
#   - Read-only validation
#   - No traffic generation
#   - No bans created
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command fail2ban-client
require_command systemctl
require_command grep
require_command nft

check_el9

STAGE_NAME="Security_Smoke_Test"
stage_begin "${STAGE_NAME}"

log_info "=== Security Smoke Test: VICIdial EL9 ==="

# -----------------------------------------------------------------------------
# 1) Fail2Ban service
# -----------------------------------------------------------------------------
log_info "Checking Fail2Ban service"

if ! systemctl is-active --quiet fail2ban; then
  fatal "Fail2Ban service is NOT running"
fi

log_success "Fail2Ban service running"

# -----------------------------------------------------------------------------
# 2) Asterisk jail enabled
# -----------------------------------------------------------------------------
log_info "Checking Asterisk jail"

JAILS="$(fail2ban-client status | sed 's/,//g')"

echo "${JAILS}" | grep -q asterisk \
  || fatal "Asterisk jail NOT found"

log_success "Asterisk jail present"

# -----------------------------------------------------------------------------
# 3) Jail status sanity
# -----------------------------------------------------------------------------
log_info "Inspecting Asterisk jail health"

JAIL_STATUS="$(fail2ban-client status asterisk)"

echo "${JAIL_STATUS}" | grep -q "Status for the jail: asterisk" \
  || fatal "Unable to query asterisk jail"

log_success "Asterisk jail responding"

# -----------------------------------------------------------------------------
# 4) Regex match verification (CRITICAL)
# -----------------------------------------------------------------------------
log_info "Verifying Fail2Ban regex matches Asterisk logs"

ASTERISK_LOG="/var/log/asterisk/messages"

if [[ ! -f "${ASTERISK_LOG}" ]]; then
  fatal "Asterisk log not found: ${ASTERISK_LOG}"
fi

if ! grep -E "Failed to authenticate|No matching endpoint found" "${ASTERISK_LOG}" >/dev/null; then
  log_warn "No failed SIP auth lines found (quiet system)"
else
  log_success "Asterisk logs contain SIP failures (expected)"
fi

# Dry-run regex test
if ! fail2ban-regex "${ASTERISK_LOG}" /etc/fail2ban/filter.d/asterisk.conf | grep -q "Lines matched"; then
  fatal "Fail2Ban regex NOT matching Asterisk logs"
fi

log_success "Fail2Ban regex matches Asterisk logs"

# -----------------------------------------------------------------------------
# 5) Ban mechanism validation
# -----------------------------------------------------------------------------
log_info "Validating ban backend (nftables)"

if ! nft list tables | grep -q fail2ban; then
  fatal "Fail2Ban nftables table NOT found"
fi

log_success "Fail2Ban nftables backend active"

# -----------------------------------------------------------------------------
# 6) Firewall baseline check
# -----------------------------------------------------------------------------
log_info "Validating firewalld"

if systemctl is-active --quiet firewalld; then
  log_success "firewalld active"
else
  log_warn "firewalld not active (ensure nftables rules exist)"
fi

# -----------------------------------------------------------------------------
# 7) Logrotate presence
# -----------------------------------------------------------------------------
log_info "Checking logrotate configuration"

for f in /etc/logrotate.d/asterisk /etc/logrotate.d/astguiclient; do
  [[ -f "$f" ]] || fatal "Missing logrotate file: $f"
done

log_success "Logrotate configs present"



log_info "Checking SSH IP whitelist"

SSH_IP="$(who am i | awk '{print $5}' | tr -d '()' || true)"

if [[ -n "${SSH_IP}" ]]; then
  grep -R "${SSH_IP}" /etc/fail2ban || fatal "SSH IP not whitelisted in Fail2Ban"
  log_success "SSH IP ${SSH_IP} whitelisted"
else
  log_warn "Unable to detect SSH IP during smoke test"
fi


# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "SECURITY SMOKE TEST PASSED"
stage_finish "${STAGE_NAME}"

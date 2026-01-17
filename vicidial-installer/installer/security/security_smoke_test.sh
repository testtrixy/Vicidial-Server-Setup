#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Security Smoke Test – VICIdial EL9
#
# Purpose:
#   - Verify Fail2Ban, nftables, firewalld, and log hygiene
#   - Detect silent security failures
#
# Safe:
#   - Read-only
#   - No bans created
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command fail2ban-client
require_command fail2ban-regex
require_command systemctl
require_command grep
require_command nft

check_el9

STAGE_NAME="Security_Smoke_Test"
stage_begin "${STAGE_NAME}"

log_info "=== Security Smoke Test: VICIdial EL9 ==="

# -----------------------------------------------------------------------------
# Fail2Ban service
# -----------------------------------------------------------------------------
systemctl is-active --quiet fail2ban \
  || fatal "Fail2Ban service is NOT running"

log_success "Fail2Ban service running"

# -----------------------------------------------------------------------------
# Asterisk jail present
# -----------------------------------------------------------------------------
fail2ban-client status | grep -q asterisk \
  || fatal "Asterisk jail NOT found"

log_success "Asterisk jail present"

# -----------------------------------------------------------------------------
# Jail responding
# -----------------------------------------------------------------------------
fail2ban-client status asterisk | grep -q "Status for the jail" \
  || fatal "Unable to query Asterisk jail"

log_success "Asterisk jail responding"

# -----------------------------------------------------------------------------
# Regex effectiveness
# -----------------------------------------------------------------------------
ASTERISK_LOG="/var/log/asterisk/messages"
FILTER="/etc/fail2ban/filter.d/asterisk.conf"

[[ -f "${ASTERISK_LOG}" ]] || fatal "Missing Asterisk log"
[[ -f "${FILTER}" ]] || fatal "Missing Fail2Ban filter"

MATCHED="$(fail2ban-regex "${ASTERISK_LOG}" "${FILTER}" | awk '/Matched lines:/ {print $3}')"

if [[ "${MATCHED:-0}" -eq 0 ]]; then
  log_warn "No matched SIP failures (quiet system)"
else
  log_success "Fail2Ban regex matching (${MATCHED} hits)"
fi

# -----------------------------------------------------------------------------
# nftables backend
# -----------------------------------------------------------------------------
nft list tables | grep -q fail2ban \
  || fatal "Fail2Ban nftables table missing"

log_success "Fail2Ban nftables backend active"

# -----------------------------------------------------------------------------
# firewalld
# -----------------------------------------------------------------------------
if systemctl is-active --quiet firewalld; then
  log_success "firewalld active"
else
  log_warn "firewalld not active (ensure nft rules exist)"
fi

# -----------------------------------------------------------------------------
# Logrotate
# -----------------------------------------------------------------------------
for f in /etc/logrotate.d/asterisk /etc/logrotate.d/astguiclient; do
  [[ -f "$f" ]] || fatal "Missing logrotate file: $f"
done

log_success "Logrotate configuration present"

# -----------------------------------------------------------------------------
# SSH whitelist (best effort)
# -----------------------------------------------------------------------------
SSH_IP="$(who am i | awk '{print $5}' | tr -d '()' || true)"

if [[ -n "${SSH_IP}" ]] && grep -R "${SSH_IP}" /etc/fail2ban >/dev/null 2>&1; then
  log_success "SSH IP ${SSH_IP} whitelisted"
else
  log_warn "SSH IP not detected or not whitelisted"
fi

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "SECURITY SMOKE TEST PASSED"
stage_finish "${STAGE_NAME}"



##############################################################################
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


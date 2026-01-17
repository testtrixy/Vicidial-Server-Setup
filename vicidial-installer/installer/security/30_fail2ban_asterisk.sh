#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Stage 30 – Fail2Ban for Asterisk / PJSIP (EL9 – Golden)
#
# Purpose:
#   - Stop SIP/PJSIP brute-force attacks
#   - Match modern Asterisk PJSIP log formats
#   - Enforce bans at nftables level (EL9 native)
#
# Safe:
#   - Idempotent
#   - No Asterisk restart
#   - No lockout unless threshold exceeded
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command dnf
require_command systemctl
require_command fail2ban-client

check_el9

STAGE_NAME="Stage_30_Fail2Ban_Asterisk"
stage_begin "${STAGE_NAME}"

log_info "=== Stage 30: Fail2Ban for Asterisk / PJSIP ==="

# -----------------------------------------------------------------------------
# Install Fail2Ban
# -----------------------------------------------------------------------------
log_info "Installing Fail2Ban"

dnf install -y fail2ban >/dev/null
systemctl enable --now fail2ban

log_success "Fail2Ban installed and running"

# -----------------------------------------------------------------------------
# Deploy known-good configs
# -----------------------------------------------------------------------------
log_info "Deploying Fail2Ban filter and jail"

mkdir -p /etc/fail2ban/filter.d

cp -f "${INSTALLER_ROOT}/security/files/fail2ban/filter.d/asterisk.conf" \
      /etc/fail2ban/filter.d/asterisk.conf

cp -f "${INSTALLER_ROOT}/security/files/fail2ban/jail.local" \
      /etc/fail2ban/jail.local

log_success "Fail2Ban configuration deployed"

# -----------------------------------------------------------------------------
# Restart Fail2Ban
# -----------------------------------------------------------------------------
log_info "Restarting Fail2Ban"

systemctl restart fail2ban
sleep 2

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
log_info "Validating Asterisk Fail2Ban jail"

fail2ban-client status asterisk >/dev/null \
  || fatal "Fail2Ban jail 'asterisk' is NOT active"

log_success "Fail2Ban Asterisk jail active"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 30 completed – SIP brute-force protection enabled"
stage_finish "${STAGE_NAME}"



 #Run :      fail2ban-client status asterisk
# Result :  enabled = true Total failed > 0 (if attacks occurred) Currently banned >= 0
#-----
# nft list ruleset | grep fail2ban



# also check 
#  fail2ban-regex \
#  /var/log/asterisk/messages \
#  /etc/fail2ban/filter.d/asterisk.conf






###############################################################################
# Stage 30 – Fail2Ban for Asterisk / PJSIP (EL9 – Golden)
#
# Purpose:
#   - Stop SIP/PJSIP brute-force attacks
#   - Match modern Asterisk PJSIP log formats
#   - Enforce bans at nftables level (EL9 native)
#
# Fixes:
#   - Regex matches IP:PORT (PJSIP)
#   - Uses systemd journal OR log file
#   - Prevents false negatives
#
# Safe:
#   - Idempotent
#   - No service restarts for Asterisk
#   - No lockout unless threshold exceeded
###############################################################################

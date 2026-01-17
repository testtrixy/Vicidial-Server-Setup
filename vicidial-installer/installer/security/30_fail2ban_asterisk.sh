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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command dnf
require_command fail2ban-client
require_command systemctl

check_el9

STAGE_NAME="Stage_30_Fail2Ban_Asterisk"
stage_begin "${STAGE_NAME}"

log_info "=== Stage 30: Fail2Ban Asterisk / PJSIP ==="

# -----------------------------------------------------------------------------
# Install Fail2Ban
# -----------------------------------------------------------------------------
log_info "Installing Fail2Ban"

dnf install -y fail2ban >/dev/null

systemctl enable --now fail2ban

log_success "Fail2Ban installed and running"

# -----------------------------------------------------------------------------
# Asterisk filter (PJSIP + SIP)
# -----------------------------------------------------------------------------
log_info "Installing Fail2Ban Asterisk filter"

cat >/etc/fail2ban/filter.d/asterisk.conf <<'EOF'
[Definition]

# PJSIP REGISTER failures (modern format)
failregex = ^.*NOTICE.*Request 'REGISTER' from '.*' failed for '<HOST>:\d+' .*Failed to authenticate
            ^.*NOTICE.*Request 'REGISTER' from '.*' failed for '<HOST>:\d+' .*No matching endpoint found
            ^.*NOTICE.*Request 'REGISTER' from '.*' failed for '<HOST>:\d+' .*after .* tries.*

# chan_sip failures (legacy)
            ^.*NOTICE.*Registration from '.*' failed for '<HOST>:\d+'.*
            ^.*WARNING.*Illegal password for .* from <HOST>
            ^.*NOTICE.*Failed to authenticate user .* from <HOST>

ignoreregex =
EOF

log_success "Fail2Ban filter installed"

# -----------------------------------------------------------------------------
# Jail configuration (EL9 / nftables)
# -----------------------------------------------------------------------------
log_info "Installing Fail2Ban jail"

cat >/etc/fail2ban/jail.d/asterisk.local <<'EOF'
[asterisk]
enabled  = true
filter   = asterisk

# SIP + PJSIP ports
port     = 5060,5061

# Use systemd journal (EL9 default)
backend  = systemd
journalmatch = _SYSTEMD_UNIT=asterisk.service

# Ban policy
maxretry = 3
findtime = 120
bantime  = 24h

# Enforce bans at kernel level
banaction = nftables-multiport

# Prevent self-lockout
ignoreip = 127.0.0.1/8 ::1
EOF

log_success "Fail2Ban jail installed"

# -----------------------------------------------------------------------------
# Restart Fail2Ban cleanly
# -----------------------------------------------------------------------------
log_info "Restarting Fail2Ban"

systemctl restart fail2ban
sleep 2

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
log_info "Validating Fail2Ban status"

fail2ban-client status asterisk >/dev/null \
  || fatal "Fail2Ban jail 'asterisk' not active"

log_success "Fail2Ban Asterisk jail active"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 30 completed – SIP brute-force protection active"
stage_finish "${STAGE_NAME}"







 #Run :      fail2ban-client status asterisk
# Result :  enabled = true Total failed > 0 (if attacks occurred) Currently banned >= 0
#-----
# nft list ruleset | grep fail2ban



# also check 
#  fail2ban-regex \
#  /var/log/asterisk/messages \
#  /etc/fail2ban/filter.d/asterisk.conf
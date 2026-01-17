#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Stage 40 – Log Rotation (Asterisk & VICIdial)
#
# Purpose:
#   - Prevent disk exhaustion from SIP bots & AMI spam
#   - Rotate Asterisk + astguiclient logs safely
#   - EL9-compatible (logrotate + systemd)
#
# Why this exists:
#   - PJSIP brute-force attempts generate massive logs
#   - EL9 will NOT rotate Asterisk logs by default
#   - Full disks silently kill VICIdial
#
# Safe:
#   - Idempotent
#   - No service restarts
#   - Compression delayed to avoid file-handle issues
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command logrotate

check_el9

STAGE_NAME="Stage_40_Logrotate"
stage_begin "${STAGE_NAME}"

log_info "=== Stage 40: Log Rotation (Asterisk & VICIdial) ==="

# -----------------------------------------------------------------------------
# 1) Asterisk log rotation
# -----------------------------------------------------------------------------
log_info "Configuring logrotate for Asterisk logs"

cat >/etc/logrotate.d/asterisk <<'EOF'
/var/log/asterisk/*.log
/var/log/asterisk/messages
/var/log/asterisk/full
{
    daily
    rotate 14
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    create 0640 asterisk asterisk
    postrotate
        /usr/sbin/asterisk -rx 'logger reload' >/dev/null 2>&1 || true
    endscript
}
EOF

log_success "Asterisk log rotation configured"

# -----------------------------------------------------------------------------
# 2) VICIdial astguiclient log rotation
# -----------------------------------------------------------------------------
log_info "Configuring logrotate for astguiclient logs"

mkdir -p /var/log/astguiclient
chown -R asterisk:asterisk /var/log/astguiclient
chmod 755 /var/log/astguiclient

cat >/etc/logrotate.d/astguiclient <<'EOF'
/var/log/astguiclient/*.log
/var/log/astguiclient/*log
{
    daily
    rotate 14
    missingok
    notifempty
    compress
    delaycompress
    create 0640 asterisk asterisk
}
EOF

log_success "astguiclient log rotation configured"

# -----------------------------------------------------------------------------
# 3) Fail2Ban log rotation (EL9 default safety)
# -----------------------------------------------------------------------------
if [[ -f /var/log/fail2ban.log ]]; then
  log_info "Configuring logrotate for Fail2Ban logs"

  cat >/etc/logrotate.d/fail2ban <<'EOF'
/var/log/fail2ban.log
{
    weekly
    rotate 8
    missingok
    notifempty
    compress
    delaycompress
    create 0640 root root
    postrotate
        /usr/bin/systemctl reload fail2ban >/dev/null 2>&1 || true
    endscript
}
EOF

  log_success "Fail2Ban log rotation configured"
else
  log_warn "Fail2Ban log not found — skipping"
fi

# -----------------------------------------------------------------------------
# 4) Immediate validation (safe)
# -----------------------------------------------------------------------------
log_info "Validating logrotate configuration"

logrotate -d /etc/logrotate.d/asterisk >/dev/null
logrotate -d /etc/logrotate.d/astguiclient >/dev/null

log_success "Logrotate configuration validated"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 40 completed – log rotation active"
stage_finish "${STAGE_NAME}"


# logrotate -f /etc/logrotate.d/asterisk
# ls -lh /var/log/asterisk
#
# messages
# messages.1
# messages.2.gz
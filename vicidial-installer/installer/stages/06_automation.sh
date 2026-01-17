#!/usr/bin/env bash
# =============================================================================
# Stage 06 – Automation & Hardening
#
# Responsibilities:
#   - Install native systemd service for Asterisk (EL9)
#   - Enable & start Asterisk (FIRST TIME)
#   - Install full Vicidial cron set (keepalive, audio, DB maintenance)
#   - Harden Asterisk AMI (localhost only)
#   - Final runtime permissions
#
# DESIGN RULE:
#   - Stage 04 builds Asterisk (NO services)
#   - Stage 06 operationalizes Asterisk (systemd + cron)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety & prerequisites
# -----------------------------------------------------------------------------
require_root
require_command systemctl
require_command crontab
require_command perl
require_command asterisk


STAGE_NAME="Stage_06a"
stage_begin "${STAGE_NAME}"

log_success "-------------------------------------------------------"
log_info "Stage 06: Vicidial automation & hardening started"
log_success "-------------------------------------------------------"

# -----------------------------------------------------------------------------
# 0. Install native systemd service for Asterisk (EL9 ONLY)
# -----------------------------------------------------------------------------
log_info "Installing native systemd service for Asterisk (EL9)"

if [[ ! -f /etc/systemd/system/asterisk.service ]]; then
  cat >/etc/systemd/system/asterisk.service <<'EOF'
[Unit]
Description=Asterisk PBX
After=network.target mariadb.service
Wants=network.target

[Service]
Type=simple
User=asterisk
Group=asterisk
RuntimeDirectory=asterisk
RuntimeDirectoryMode=0755
ExecStart=/usr/sbin/asterisk -f -vvvg
ExecReload=/usr/sbin/asterisk -rx 'core reload'
ExecStop=/usr/sbin/asterisk -rx 'core stop now'
Restart=always
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable asterisk
systemctl start asterisk

# -----------------------------------------------------------------------------
# 1. Verify Asterisk is actually running (FAIL FAST)
# -----------------------------------------------------------------------------
log_info "Verifying Asterisk runtime"

if ! asterisk -rx "core show uptime" >/dev/null 2>&1; then
  fatal "Asterisk failed to start – automation cannot continue"
fi

log_success "Asterisk is running and responsive"

# -----------------------------------------------------------------------------
# 2. Vicidial cron jobs (FULL, production-safe set)
# -----------------------------------------------------------------------------
VICIDIAL_HOME="/usr/share/astguiclient"
CRON_USER="root"

require_dir "${VICIDIAL_HOME}"

log_info "Installing Vicidial cron jobs"

CRON_FILE="/tmp/vicidial.cron"

cat <<'EOF' > "${CRON_FILE}"
### ============================
### VICIDIAL CORE CRON JOBS
### ============================

# --- Keepalive (CRITICAL) ---
* * * * * /usr/bin/perl /usr/share/astguiclient/ADMIN_keepalive_ALL.pl

# --- Dialer & Core ---
* * * * * /usr/bin/perl /usr/share/astguiclient/AST_manager_send.pl
* * * * * /usr/bin/perl /usr/share/astguiclient/AST_update.pl
* * * * * /usr/bin/perl /usr/share/astguiclient/AST_update_phones.pl
* * * * * /usr/bin/perl /usr/share/astguiclient/AST_update_user_groups.pl

# --- Audio processing ---
1 1 * * * /usr/bin/perl /usr/share/astguiclient/AST_CRON_audio_1_move_mix.pl
2 1 * * * /usr/bin/perl /usr/share/astguiclient/AST_CRON_audio_2_compress.pl --MP3

# --- Log & DB archive (CRITICAL – prevents disk fill) ---
30 2 * * * /usr/bin/perl /usr/share/astguiclient/ADMIN_archive_log_tables.pl
15 3 * * * /usr/bin/perl /usr/share/astguiclient/AST_cleanup_log_files.pl
EOF

# Install crontab safely (idempotent)
crontab -l 2>/dev/null | grep -v astguiclient > /tmp/cron.clean || true
cat /tmp/cron.clean "${CRON_FILE}" | crontab -
rm -f /tmp/cron.clean "${CRON_FILE}"

log_success "Vicidial cron jobs installed"

# -----------------------------------------------------------------------------
# 3. Harden Asterisk Manager Interface (AMI)
# -----------------------------------------------------------------------------
log_info "Hardening Asterisk AMI (localhost only)"

cat >/etc/asterisk/manager.conf <<'EOF'
[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1
displayconnects = no

[cron]
secret = 1234
read = system,call,log,verbose,command,agent,user,originate
write = system,call,log,verbose,command,agent,user,originate
EOF

asterisk -rx "manager reload" || true


asterisk -rx "manager show settings" | grep -q "Yes" \
  || fatal "AMI not enabled"


  asterisk -rx "sip show peers" >/dev/null 2>&1 \
  || fatal "SIP runtime unavailable"

# -----------------------------------------------------------------------------
# 4. Final permissions
# -----------------------------------------------------------------------------
log_info "Applying final permissions"

chown -R asterisk:asterisk /var/log/asterisk /var/lib/asterisk /var/spool/asterisk
chmod -R 750 /var/log/asterisk /var/lib/asterisk /var/spool/asterisk

chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html




###############################################################################
# Security: Firewall Baseline (EL9 nftables)
###############################################################################

log_info "Applying firewall baseline (security/20)"

SECURITY_FW="${INSTALLER_ROOT}/security/20_firewall_baseline.sh"
[[ -x "${SECURITY_FW}" ]] || fatal "Missing ${SECURITY_FW}"

bash "${SECURITY_FW}"

###############################################################################
# Security: Fail2Ban for Asterisk (PJSIP aware)
###############################################################################

log_info "Applying Fail2Ban protection (security/30)"

SECURITY_F2B="${INSTALLER_ROOT}/security/30_fail2ban_asterisk.sh"
[[ -x "${SECURITY_F2B}" ]] || fatal "Missing ${SECURITY_F2B}"

bash "${SECURITY_F2B}"


###############################################################################
# Security: Log Rotation
###############################################################################

log_info "Installing Asterisk log rotation (security/40)"

SECURITY_LOGROTATE="${INSTALLER_ROOT}/security/40_logrotate.sh"
[[ -x "${SECURITY_LOGROTATE}" ]] || fatal "Missing ${SECURITY_LOGROTATE}"

bash "${SECURITY_LOGROTATE}"




# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------

log_success "Stage 06 completed – Vicidial automation & hardening done"
stage_finish "${STAGE_NAME}"
#!/usr/bin/env bash
# =============================================================================
# Stage 06 – Automation & Hardening
# Responsibilities:
#   - Install full Vicidial cron set (keepalive, audio, DB maintenance)
#   - Harden Asterisk AMI (localhost only, cron user)
#   - Ensure Asterisk service reliability (systemd drop-in)
#   - Final runtime permissions
#
# ASSUMES:
#   - Stages 01–05 completed
#   - Vicidial core installed in /usr/share/astguiclient
#   - Asterisk running
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety & prerequisites
# -----------------------------------------------------------------------------
require_root
require_command crontab
require_command asterisk
require_command perl



log_success "---------------- – -------------------------------"
 log_info "Stage 06: Vicidial automation & hardening started"
log_success "---------------- – -------------------------------"



log_info "-------------------------------------------------------"
 log_info "Starting Asterisk - at Stage 6"
log_info "-------------------------------------------------------"


# -----------------------------------------------------------------------------
# 0. Ensure Asterisk systemd service (EL9 native)
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

log_info "-----------------------------------------------------------------------"







VICIDIAL_HOME="/usr/share/astguiclient"
CRON_USER="root"

require_dir "${VICIDIAL_HOME}"

# -----------------------------------------------------------------------------
# 1. Vicidial Cron Jobs (FULL SET – production safe)
# -----------------------------------------------------------------------------
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
* * * * * /usr/bin/perl /usr/share/astguiclient/AST*

# --- Log & DB archive (CRITICAL) ---

30 2 * * * /usr/bin/perl /usr/share/astguiclient/ADMIN_archive_log_tables.pl
15 3 * * * /usr/bin/perl /usr/share/astguiclient/AST_cleanup_log_files.pl


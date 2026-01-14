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

log_info "Stage 06: Vicidial automation & hardening started"

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

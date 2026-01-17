#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Stage 05 – Vicidial Core (EL9 – Golden)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"

require_root
require_command perl
require_command mysql
require_command systemctl

# Canonical DB access (no sockets, no localhost)
DB_HOST="127.0.0.1"
DB_SOCKET=""

STAGE_NAME="Stage_05"
stage_begin "${STAGE_NAME}"

log_info "=== Stage 05: Vicidial Core (EL9) ==="

# -----------------------------------------------------------------------------
# OS Guard
# -----------------------------------------------------------------------------
check_el9

# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------
require_vars \
  VICIDIAL_DB_HOST \
  VICIDIAL_DB_NAME \
  VICIDIAL_DB_USER \
  VICIDIAL_DB_PASS \
  VICIDIAL_AST_USER \
  VICIDIAL_AST_GROUP

# -----------------------------------------------------------------------------
# Database Preflight (Authoritative)
# -----------------------------------------------------------------------------
log_info "Running database preflight (DBI/MariaDB)"
db_preflight

# -----------------------------------------------------------------------------
# Verify Vicidial Core Exists
# -----------------------------------------------------------------------------
[[ -d /usr/share/astguiclient ]] \
  || fatal "Vicidial core missing. Stage 04 must complete first."

# -----------------------------------------------------------------------------
# Detect MariaDB Socket
# -----------------------------------------------------------------------------
DB_SOCKET="$(get_mariadb_socket)"
log_info "Detected MariaDB socket: ${DB_SOCKET}"

# -----------------------------------------------------------------------------
# Generate astguiclient.conf
# -----------------------------------------------------------------------------

ASTGUI_CONF="/etc/astguiclient.conf"
log_info "Generating ${ASTGUI_CONF}"

cat > "${ASTGUI_CONF}" <<EOF
VARDB_server=${VICIDIAL_DB_HOST}
VARDB_database=${VICIDIAL_DB_NAME}
VARDB_user=${VICIDIAL_DB_USER}
VARDB_pass=${VICIDIAL_DB_PASS}
VARDB_port=3306
VARDB_socket=${DB_SOCKET}

PATHhome=/usr/share/astguiclient
PATHlogs=/var/log/astguiclient
PATHagi=/var/lib/asterisk/agi-bin
PATHweb=/var/www/html
PATHsounds=/var/lib/asterisk/sounds
PATHmonitor=/var/spool/asterisk/monitor
PATHDONEmonitor=/var/spool/asterisk/monitorDONE

ASTuser=${VICIDIAL_AST_USER}
ASTgroup=${VICIDIAL_AST_GROUP}
EOF

chmod 600 "${ASTGUI_CONF}"
chown root:root "${ASTGUI_CONF}"


grep -q "VARDB_server => 127.0.0.1" /etc/astguiclient.conf \
  || fatal "DB host misconfigured in astguiclient.conf"



# -----------------------------------------------------------------------------
# Stage 05.6 – VICIdial Asterisk 18 Compatibility (AMI regex)
# -----------------------------------------------------------------------------

log_info "Applying VICIdial Asterisk 18 compatibility patch (AMI regex)"

for f in \
  /usr/share/astguiclient/AST_update.pl \
  /usr/share/astguiclient/AST_manager_send.pl
do
  [[ -f "$f" ]] || fatal "Missing VICIdial script: $f"
  perl -pi -e 's/\[0123\]/[0-9]/g' "$f"
done

log_success "VICIdial AMI regex compatibility patch applied"



# -----------------------------------------------------------------------------
# Install MASTER Vicidial Cron
# -----------------------------------------------------------------------------
log_info "Installing Vicidial Master Cron"

#CRON_SRC="${INSTALLER_ROOT}/templates/cron/vicidial.cron.tpl"
#CRON_DST="/etc/cron.d/vicidial"
#[[ -f "${CRON_SRC}" ]] || fatal "Missing ${CRON_SRC}"
#cp -f "${CRON_SRC}" "${CRON_DST}"
#chmod 644 "${CRON_DST}"
#chown root:root "${CRON_DST}"


NODE_ROLE="${NODE_ROLE:-dialer}"
CRON_DST="/etc/cron.d/vicidial"

case "${NODE_ROLE}" in
  dialer|all)
    CRON_SRC="${INSTALLER_ROOT}/templates/cron/vicidial.dialer.cron.tpl"
    ;;
  db)
    CRON_SRC="${INSTALLER_ROOT}/templates/cron/vicidial.db.cron.tpl"
    ;;
  web)
    log_info "Web node detected – no Vicidial cron installed"
    exit 0
    ;;
  *)
    fatal "Unknown NODE_ROLE=${NODE_ROLE}"
    ;;
esac

# -----------------------------------------------------------------------------
# Validate Cron Engine
# -----------------------------------------------------------------------------
log_info "Validating cron engine"

log_info "Installing Vicidial cron for role: ${NODE_ROLE}"

ensure_vicidial_cron "${CRON_SRC}"

log_success "Vicidial cron engine installed and validated"

# -----------------------------------------------------------------------------
# Permissions
# -----------------------------------------------------------------------------
mkdir -p /var/log/astguiclient
chown -R "${VICIDIAL_AST_USER}:${VICIDIAL_AST_GROUP}" /var/log/astguiclient
chmod -R 755 /var/log/astguiclient


# -----------------------------------------------------------------------------
# Stage 05.7 – VICIdial AMI Listener (systemd)
# -----------------------------------------------------------------------------
log_info "Installing VICIdial AMI listener systemd service"

cat >/etc/systemd/system/vicidial-ami-listener.service <<'EOF'
[Unit]
Description=VICIdial AMI Listener
After=asterisk.service mariadb.service network.target
Requires=asterisk.service

[Service]
Type=simple
User=asterisk
Group=asterisk
ExecStart=/usr/share/astguiclient/AST_manager_listen.pl
Restart=always
RestartSec=5
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vicidial-ami-listener

log_success "VICIdial AMI listener enabled and started"





# -----------------------------------------------------------------------------
# Stage 05.8 – Verify AMI Listener Health
# -----------------------------------------------------------------------------
log_info "Verifying VICIdial AMI listener health"

if ! systemctl is-active --quiet vicidial-ami-listener; then
  fatal "VICIdial AMI listener is not running"
fi

log_success "VICIdial AMI listener verified healthy"


#
#

log_success "Stage 05 completed – Vicidial Core & Cron Engine active"
stage_finish "${STAGE_NAME}"

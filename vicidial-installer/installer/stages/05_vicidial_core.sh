#!/usr/bin/env bash
# =============================================================================
# Stage 05 – Vicidial Core Installation (EL9 / Production)
#
# Responsibilities:
#   - Install required Perl modules
#   - Build DBD::mysql (pinned 4.050 – EL9 compatible)
#   - Deploy Vicidial from official nightly ZIP
#   - Import database schema (idempotent)
#   - Generate astguiclient.conf
#   - Install web UI
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety & prerequisites
# -----------------------------------------------------------------------------
require_root
require_command perl
require_command mysql
require_command unzip
require_command cpan

log_info "Stage 05: Vicidial core installation started"

# -----------------------------------------------------------------------------
# Verify asterisk system user exists (Stage 01 dependency)
# -----------------------------------------------------------------------------
if ! getent passwd asterisk >/dev/null; then
  fatal "asterisk system user does not exist. Stage 01 must be completed first."
fi

# -----------------------------------------------------------------------------
# Perl system dependencies (NO MariaDB Perl driver here)
# -----------------------------------------------------------------------------
log_info "Installing required Perl system dependencies"

dnf -y install \
  perl-DBI \
  perl-Net-Telnet \
  perl-Time-HiRes \
  perl-Net-Server \
  perl-Term-ReadLine-Gnu \
  perl-LWP-Protocol-https \
  perl-Sys-Syslog \
  perl-libwww-perl \
  perl-JSON \
  perl-ExtUtils-MakeMaker \
  gcc \
  make \
  mariadb-connector-c-devel

# -----------------------------------------------------------------------------
# CPAN non-interactive configuration (CRITICAL)
# -----------------------------------------------------------------------------
export PERL_MM_USE_DEFAULT=1
export PERL_EXTUTILS_AUTOINSTALL="--defaultdeps"
export PERL5_CPAN_IS_RUNNING=1

# -----------------------------------------------------------------------------
# Ensure DBD::mysql exists (EL9 requires pinned build)
# -----------------------------------------------------------------------------
log_info "Ensuring DBD::mysql is available (EL9 pinned build)"

if ! perl -MDBD::mysql -e 1 >/dev/null 2>&1; then
  log_warn "DBD::mysql not found – building pinned version 4.050"
  cpan -T DVEEDEN/DBD-mysql-4.050.tar.gz
fi

perl -MDBD::mysql -e 'print "DBD::mysql OK\n"' \
  || fatal "DBD::mysql installation failed"

# -----------------------------------------------------------------------------
# Vicidial source (official nightly ZIP)
# -----------------------------------------------------------------------------
VICIDIAL_BUILD_DATE="2026-01-13"
VICIDIAL_ZIP="vicidial-trunk-${VICIDIAL_BUILD_DATE}.zip"
VICIDIAL_URL="https://www.vicidial.org/svn_trunk_nightly/${VICIDIAL_ZIP}"

VICIDIAL_BASE="${INSTALLER_ROOT}/tools/vicidial"


mkdir -p "${VICIDIAL_BASE}"
cd "${VICIDIAL_BASE}"

if [[ ! -d "${VICIDIAL_BUILD_DATE}" ]]; then
  log_info "Downloading Vicidial ${VICIDIAL_BUILD_DATE}"
  curl -fLO "${VICIDIAL_URL}"
  unzip -q "${VICIDIAL_ZIP}"
fi

VICIDIAL_SRC_DIR="${VICIDIAL_BASE}/${VICIDIAL_BUILD_DATE}"
[[ -d "${VICIDIAL_SRC_DIR}" ]] || fatal "Vicidial source directory not found"

log_info "Using Vicidial source directory: ${VICIDIAL_SRC_DIR}"

# -----------------------------------------------------------------------------
# Filesystem layout
# -----------------------------------------------------------------------------
ASTGUI_HOME="/usr/share/astguiclient"
ASTGUI_LOGS="/var/log/astguiclient"
AST_AGI="/var/lib/asterisk/agi-bin"
AST_SOUNDS="/var/lib/asterisk/sounds"
AST_MONITOR="/var/spool/asterisk/monitor"
VICIDIAL_WEB_ROOT="/var/www/html/vicidial"

log_info "Creating Vicidial filesystem layout"

mkdir -p \
  "${ASTGUI_HOME}" \
  "${ASTGUI_LOGS}" \
  "${AST_AGI}" \
  "${AST_SOUNDS}" \
  "${AST_MONITOR}" \
  "$(dirname "${VICIDIAL_WEB_ROOT}")"

# -----------------------------------------------------------------------------
# Install Vicidial components
# -----------------------------------------------------------------------------
log_info "Installing Vicidial components"

cp -r "${VICIDIAL_SRC_DIR}/agi"     "${ASTGUI_HOME}/"
cp -r "${VICIDIAL_SRC_DIR}/bin"     "${ASTGUI_HOME}/"
cp -r "${VICIDIAL_SRC_DIR}/libs"    "${ASTGUI_HOME}/"
cp -r "${VICIDIAL_SRC_DIR}/sounds"  "${AST_SOUNDS}/"



log_info "Installing Vicidial web interface with WWW"
log_info "${VICIDIAL_SRC_DIR}/www"

WEB_SRC="${VICIDIAL_SRC_DIR}/www"
if [[ ! -d "${WEB_SRC}" ]]; then
  fatal "Vicidial web directory not found at ${WEB_SRC}"
fi
cp -r "${WEB_SRC}" "${VICIDIAL_WEB_ROOT}"

#cp -r "${VICIDIAL_SRC_DIR}/www"     "${VICIDIAL_WEB_ROOT}"



# -----------------------------------------------------------------------------
# Permissions
# -----------------------------------------------------------------------------
log_info "Setting Vicidial permissions"

chown -R asterisk:asterisk \
  "${ASTGUI_HOME}" \
  "${ASTGUI_LOGS}" \
  "${AST_AGI}" \
  "${AST_SOUNDS}" \
  "${AST_MONITOR}"

chown -R apache:apache "${VICIDIAL_WEB_ROOT}"

chmod -R 755 "${VICIDIAL_WEB_ROOT}"
chmod -R 755 "${ASTGUI_HOME}"

# -----------------------------------------------------------------------------
# Database schema import (idempotent)
# -----------------------------------------------------------------------------
log_info "Importing Vicidial database schema (if required)"

TABLE_EXISTS=$(mysql -N -B -u root asterisk \
  -e "SHOW TABLES LIKE 'phones';" || true)

if [[ -z "${TABLE_EXISTS}" ]]; then
  mysql -u root asterisk < "${VICIDIAL_SRC_DIR}/extras/MySQL_AST_CREATE_tables.sql"
else
  log_info "Vicidial tables already exist – skipping schema import"
fi

# -----------------------------------------------------------------------------
# Generate astguiclient.conf
# -----------------------------------------------------------------------------
log_info "Generating /etc/astguiclient.conf"

VARserver_ip="$(hostname -I | awk '{print $1}')"
VARDB_server="localhost"
VARDB_port="3306"

export \
  ASTGUI_HOME ASTGUI_LOGS AST_AGI AST_SOUNDS AST_MONITOR \
  VARserver_ip VARDB_server VARDB_port \
  VICIDIAL_DB_NAME VICIDIAL_DB_USER VICIDIAL_DB_PASS

render_template \
  "${INSTALLER_ROOT}/templates/vicidial/astguiclient.conf.tpl" \
  "/etc/astguiclient.conf" \
  0644 root:root

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 05 completed – Vicidial core installed successfully"

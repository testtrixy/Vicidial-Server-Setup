#!/usr/bin/env bash
# =============================================================================
# Stage 05 – Vicidial Core (ZIP-based, EL9 + MariaDB safe)
#
# Responsibilities:
#   - Install Vicidial Perl dependencies
#   - Ensure Perl DB compatibility (DBD::mysql → MariaDB)
#   - Download & extract Vicidial nightly ZIP
#   - Install Vicidial components (flat ZIP layout)
#   - Import Vicidial database schema (idempotent)
#   - Generate astguiclient.conf (template-driven)
#   - Run install.pl non-interactively
#
# Notes:
#   - Designed for Rocky/Alma EL9
#   - No SVN assumptions
#   - No MySQL RPM conflicts
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety
# -----------------------------------------------------------------------------
require_root
require_command dnf
require_command perl
require_command mysql
require_command unzip
require_command curl

log_success "---------------- – -------------------------------"
log_info "Stage 05: Vicidial core installation started"
log_success "---------------- – -------------------------------"

# -----------------------------------------------------------------------------
# Required variables
# -----------------------------------------------------------------------------
require_vars \
  INSTALLER_ROOT \
  VICIDIAL_DB_NAME \
  VICIDIAL_DB_USER \
  VICIDIAL_DB_PASS

# -----------------------------------------------------------------------------
# Paths (single source of truth)
# -----------------------------------------------------------------------------
VICIDIAL_BASE="${INSTALLER_ROOT}/tools/vicidial"

ASTGUI_HOME="/usr/share/astguiclient"
ASTGUI_LOGS="/var/log/astguiclient"
AST_AGI="/var/lib/asterisk/agi-bin"
VICIDIAL_WEB_ROOT="/var/www/html/vicidial"
AST_SOUNDS="/var/lib/asterisk/sounds"
AST_MONITOR="/var/spool/asterisk/monitor"

mkdir -p "${VICIDIAL_BASE}"

# -----------------------------------------------------------------------------
# Perl system dependencies (MariaDB-safe)
# -----------------------------------------------------------------------------
log_info "Installing Vicidial Perl dependencies"

dnf -y install \
  perl-DBI \
  perl-DBD-MariaDB \
  perl-Net-Telnet \
  perl-Time-HiRes \
  perl-Net-Server \
  perl-Term-ReadLine-Gnu \
  perl-LWP-Protocol-https \
  perl-Sys-Syslog \
  perl-libwww-perl \
  perl-JSON

# -----------------------------------------------------------------------------
# Perl DBD::mysql compatibility (EL9 MariaDB fix)
# -----------------------------------------------------------------------------
log_info "Ensuring Perl DBD::mysql compatibility (MariaDB)"

if [[ ! -f /usr/lib64/perl5/DBD/mysql.pm ]]; then
  mkdir -p /usr/lib64/perl5/DBD
  ln -s /usr/lib64/perl5/DBD/MariaDB.pm /usr/lib64/perl5/DBD/mysql.pm
fi

# -----------------------------------------------------------------------------
# CPAN modules required by Vicidial
# -----------------------------------------------------------------------------
log_info "Installing required CPAN modules"

if ! command -v cpanm >/dev/null 2>&1; then
  curl -fsSL https://cpanmin.us | perl - --sudo App::cpanminus
fi

CPAN_MODULES=(
  "MD5"
  "Digest::MD5"
  "Digest::SHA1"
  "Net::Address::IP::Local"
  "Net::Address::IPv4::Local"
  "String::CRC"
  "Spreadsheet::Read"
  "Spreadsheet::XLSX"
)

for module in "${CPAN_MODULES[@]}"; do
  log_info "Installing CPAN module: ${module}"
  cpanm --notest "${module}"
done

# -----------------------------------------------------------------------------
# Download & extract Vicidial nightly ZIP
# -----------------------------------------------------------------------------
log_info "Deploying Vicidial from official nightly ZIP"

cd "${VICIDIAL_BASE}"

rm -f vicidial-trunk-*.zip
rm -rf 20[0-9][0-9][0-9]-*

curl -fLO "https://www.vicidial.org/svn_trunk_nightly/vicidial-trunk-2026-01-13.zip"

ZIP_FILE="$(ls vicidial-trunk-*.zip | head -n1)"
unzip -q "${ZIP_FILE}"

VICIDIAL_SRC_DIR="$(find . -maxdepth 1 -type d -name '20*' | sort | tail -n1)"
[[ -d "${VICIDIAL_SRC_DIR}" ]] || fatal "Vicidial source directory not found after unzip"

log_info "Using Vicidial source directory: ${VICIDIAL_SRC_DIR}"

# -----------------------------------------------------------------------------
# Create Vicidial filesystem layout
# -----------------------------------------------------------------------------
log_info "Creating Vicidial filesystem layout"

mkdir -p \
  "${ASTGUI_HOME}" \
  "${ASTGUI_LOGS}" \
  "${AST_AGI}" \
  "${AST_MONITOR}"

# -----------------------------------------------------------------------------
# Install Vicidial components (ZIP layout)
# -----------------------------------------------------------------------------
log_info "Installing Vicidial components"

cp -r "${VICIDIAL_SRC_DIR}/bin/"* "${ASTGUI_HOME}/"
cp -r "${VICIDIAL_SRC_DIR}/agi/"* "${AST_AGI}/"
cp -r "${VICIDIAL_SRC_DIR}/sounds/"* "${AST_SOUNDS}/" || true

# -----------------------------------------------------------------------------
# Permissions
# -----------------------------------------------------------------------------
log_info "Setting Vicidial permissions"

chown -R asterisk:asterisk \
  "${ASTGUI_HOME}" \
  "${ASTGUI_LOGS}" \
  "${AST_AGI}" \
  "${AST_MONITOR}"

chmod -R 755 "${ASTGUI_HOME}"

# -----------------------------------------------------------------------------
# Import Vicidial database schema (idempotent)
# -----------------------------------------------------------------------------
log_info "Checking if Vicidial schema already exists"

if mysql -u root -e "USE ${VICIDIAL_DB_NAME}; SHOW TABLES LIKE 'phones';" | grep -q phones; then
  log_warn "Vicidial schema already exists, skipping SQL import"
else
  log_info "Importing Vicidial database schema"
  mysql -u root "${VICIDIAL_DB_NAME}" < \
    "${VICIDIAL_SRC_DIR}/extras/MySQL_AST_CREATE_tables.sql"
fi

# -----------------------------------------------------------------------------
# Vicidial runtime variables (derived, single source of truth)
# -----------------------------------------------------------------------------
log_info "Defining Vicidial runtime variables"

PATHhome="${ASTGUI_HOME}"
PATHlogs="${ASTGUI_LOGS}"
PATHagi="${AST_AGI}"
PATHweb="${VICIDIAL_WEB_ROOT}"
PATHsounds="${AST_SOUNDS}"
PATHmonitor="${AST_MONITOR}"

VARserver_ip="$(hostname -I | awk '{print $1}')"
VARDB_server="localhost"
VARDB_port="3306"

export \
  PATHhome PATHlogs PATHagi PATHweb PATHsounds PATHmonitor \
  VARserver_ip VARDB_server VARDB_port

# -----------------------------------------------------------------------------
# Generate astguiclient.conf
# -----------------------------------------------------------------------------
log_info "Generating /etc/astguiclient.conf"

render_template \
  "${INSTALLER_ROOT}/templates/vicidial/astguiclient.conf.tpl" \
  "/etc/astguiclient.conf" \
  0644 root:root

# -----------------------------------------------------------------------------
# Run Vicidial installer (non-interactive)
# -----------------------------------------------------------------------------
log_info "Running Vicidial install.pl (non-interactive)"

cd "${VICIDIAL_SRC_DIR}"
perl ./install.pl --no-prompt --copy_sample_conf

# -----------------------------------------------------------------------------
# Web interface
# -----------------------------------------------------------------------------
log_info "Installing Vicidial web interface"

rm -rf "${VICIDIAL_WEB_ROOT}"
cp -r "${VICIDIAL_SRC_DIR}/www" "${VICIDIAL_WEB_ROOT}"

chown -R apache:apache "${VICIDIAL_WEB_ROOT}"
chmod -R 755 "${VICIDIAL_WEB_ROOT}"

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 05 completed – Vicidial core installed successfully"

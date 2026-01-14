#!/usr/bin/env bash
# =============================================================================
# Stage 05 – Vicidial Core (ZIP-based, EL9 safe)
#
# Responsibilities:
#   - Install Vicidial Perl runtime dependencies (MariaDB-safe)
#   - Install CPAN modules via cpanm
#   - Deploy Vicidial from official nightly ZIP (flat layout)
#   - Create Vicidial filesystem layout
#   - Import Vicidial database schema
#   - Generate astguiclient.conf (template-driven)
#   - Run install.pl non-interactively
#
# NOTES:
#   - Uses ZIP layout (NO astguiclient/ dir in source)
#   - Compatible with MariaDB 10.11 (no MySQL RPMs)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety & prerequisites
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
  VICIDIAL_DB_USER \
  VICIDIAL_DB_PASS \
  VICIDIAL_DB_NAME \
  INSTALLER_ROOT


# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Vicidial runtime variables (derived, single source of truth)
# -----------------------------------------------------------------------------
log_info "Defining Vicidial runtime variables"

# Installer / filesystem paths (authoritative)
ASTGUI_HOME="/usr/share/astguiclient"
ASTGUI_LOGS="/var/log/astguiclient"
AST_AGI="/var/lib/asterisk/agi-bin"
VICIDIAL_WEB_ROOT="/var/www/html/vicidial"
AST_SOUNDS="/var/lib/asterisk/sounds"
AST_MONITOR="/var/spool/asterisk/monitor"

# Vicidial runtime variables (used by astguiclient.conf)
PATHhome="${ASTGUI_HOME}"
PATHlogs="${ASTGUI_LOGS}"
PATHagi="${AST_AGI}"
PATHweb="${VICIDIAL_WEB_ROOT}"
PATHsounds="${AST_SOUNDS}"
PATHmonitor="${AST_MONITOR}"

VARserver_ip="$(hostname -I | awk '{print $1}')"
VARDB_server="localhost"
VARDB_port="3306"

# Export for render_template()
export \
  PATHhome PATHlogs PATHagi PATHweb PATHsounds PATHmonitor \
  VARserver_ip VARDB_server VARDB_port



#------------------------------------------------------------


VICIDIAL_ZIP_URL="https://www.vicidial.org/svn_trunk_nightly/vicidial-trunk-2026-01-13.zip"

mkdir -p "${VICIDIAL_BASE}"

# -----------------------------------------------------------------------------
# Perl system dependencies (MariaDB-safe)
# -----------------------------------------------------------------------------
log_info "Installing Perl system dependencies (MariaDB-safe)"

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
# cpanminus
# -----------------------------------------------------------------------------
log_info "Ensuring cpanminus is installed"

if ! command -v cpanm >/dev/null 2>&1; then
  curl -fsSL https://cpanmin.us | perl - --sudo App::cpanminus
fi

require_command cpanm

# -----------------------------------------------------------------------------
# CPAN modules required by Vicidial
# -----------------------------------------------------------------------------
log_info "Installing required CPAN modules"

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
rm -rf 20* vicidial-trunk*.zip

curl -fLO "${VICIDIAL_ZIP_URL}"

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
  "${AST_AGI}"

# -----------------------------------------------------------------------------
# Copy Vicidial components (ZIP layout aware)
# -----------------------------------------------------------------------------
log_info "Installing Vicidial components"

cp -r "${VICIDIAL_SRC_DIR}/bin/"*        "${ASTGUI_HOME}/"
cp -r "${VICIDIAL_SRC_DIR}/agi/"*        "${AST_AGI}/"
cp -r "${VICIDIAL_SRC_DIR}/sounds/"*     /var/lib/asterisk/sounds/ || true

# -----------------------------------------------------------------------------
# Permissions
# -----------------------------------------------------------------------------
log_info "Setting Vicidial permissions"

chown -R asterisk:asterisk \
  "${ASTGUI_HOME}" \
  "${ASTGUI_LOGS}" \
  "${AST_AGI}"

chmod -R 755 "${ASTGUI_HOME}"

# -----------------------------------------------------------------------------
# Database schema import
# -----------------------------------------------------------------------------
log_info "Importing Vicidial database schema"
log_info "Checking if Vicidial schema already exists"


if mysql -u root -e "USE ${VICIDIAL_DB_NAME}; SHOW TABLES LIKE 'phones';" | grep -q phones; then
  log_warn "Vicidial schema already exists, skipping SQL import"
else
  log_info "Importing Vicidial database schema"
  mysql -u root "${VICIDIAL_DB_NAME}" < "${VICIDIAL_SRC_DIR}/extras/MySQL_AST_CREATE_tables.sql"
fi



# -----------------------------------------------------------------------------
# Generate astguiclient.conf
# -----------------------------------------------------------------------------
log_info "Generating /etc/astguiclient.conf"

require_vars \
  PATHhome PATHlogs PATHagi PATHweb PATHsounds PATHmonitor \
  VARserver_ip VARDB_server VARDB_port

render_template \
  "${INSTALLER_ROOT}/templates/vicidial/astguiclient.conf.tpl" \
  "/etc/astguiclient.conf" \
  0644 root:root

# -----------------------------------------------------------------------------
# Run install.pl (non-interactive)
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

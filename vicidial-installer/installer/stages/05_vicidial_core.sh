#!/usr/bin/env bash
# =============================================================================
# Stage 05 – Vicidial Core
# Responsibilities:
#   - Install Vicidial Perl runtime dependencies
#   - Install CPAN modules via cpanm
#   - Deploy Vicidial from official nightly ZIP
#   - Generate astguiclient.conf (template-driven)
#   - Import Vicidial schema
#   - Run install.pl non-interactively
#
# ASSUMES:
#   - Stages 01–04 completed
#   - MariaDB running
#   - Apache + PHP installed
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



log_success "---------------- – -------------------------------"
  log_info "Stage 05: Vicidial core installation started"
log_success "---------------- – -------------------------------"



# -----------------------------------------------------------------------------
# Required secrets & paths
# -----------------------------------------------------------------------------
require_vars VICIDIAL_DB_USER VICIDIAL_DB_PASS VICIDIAL_DB_NAME

VICIDIAL_SRC_DIR="/usr/share/astguiclient"
VICIDIAL_TMP_DIR="${INSTALLER_ROOT}/tools/vicidial"
VICIDIAL_ZIP_URL="https://www.vicidial.org/svn_trunk_nightly/vicidial-trunk-2026-01-13.zip"
VICIDIAL_ZIP_FILE="${VICIDIAL_TMP_DIR}/vicidial-trunk.zip"

# -----------------------------------------------------------------------------
# Perl system dependencies (RPM)
# -----------------------------------------------------------------------------
log_info "Installing Perl system dependencies"

dnf -y install \
  perl-DBI \
  perl-DBD-MySQL \
  perl-Net-Telnet \
  perl-Time-HiRes \
  perl-Net-Server \
  perl-Term-ReadLine-Gnu \
  perl-LWP-Protocol-https \
  perl-Sys-Syslog \
  perl-libwww-perl \
  perl-JSON

# -----------------------------------------------------------------------------
# cpanminus (cpanm)
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
# Download & extract Vicidial (official nightly ZIP)
# -----------------------------------------------------------------------------
log_info "Deploying Vicidial from official nightly ZIP"

mkdir -p "${VICIDIAL_TMP_DIR}"
cd "${VICIDIAL_TMP_DIR}"

if [[ ! -f "${VICIDIAL_ZIP_FILE}" ]]; then
  curl -fLo "${VICIDIAL_ZIP_FILE}" "${VICIDIAL_ZIP_URL}"
fi

rm -rf vicidial-trunk
unzip -q "${VICIDIAL_ZIP_FILE}"

# The ZIP extracts into vicidial-trunk/
if [[ ! -d "vicidial-trunk" ]]; then
  fatal "Vicidial ZIP extraction failed"
fi

rm -rf "${VICIDIAL_SRC_DIR}"
mv vicidial-trunk "${VICIDIAL_SRC_DIR}"

# -----------------------------------------------------------------------------
# Permissions (critical for Vicidial)
# -----------------------------------------------------------------------------
log_info "Setting Vicidial filesystem permissions"

mkdir -p /var/log/astguiclient
chown -R apache:apache "${VICIDIAL_SRC_DIR}" /var/log/astguiclient
chmod -R 755 "${VICIDIAL_SRC_DIR}"

# -----------------------------------------------------------------------------
# Database schema import (Vicidial-native)
# -----------------------------------------------------------------------------
log_info "Importing Vicidial database schema"

mysql -u"${VICIDIAL_DB_USER}" -p"${VICIDIAL_DB_PASS}" "${VICIDIAL_DB_NAME}" \
  < "${VICIDIAL_SRC_DIR}/extras/MySQL_AST_CREATE_tables.sql"

# -----------------------------------------------------------------------------
# Generate astguiclient.conf (template-driven)
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
# Run Vicidial install.pl (non-interactive)
# -----------------------------------------------------------------------------
log_info "Running Vicidial install.pl (non-interactive)"

cd "${VICIDIAL_SRC_DIR}"
perl install.pl --no-prompt --copy_sample_conf

# -----------------------------------------------------------------------------
# Web symlink
# -----------------------------------------------------------------------------
log_info "Linking Vicidial web interface"

ln -sf "${VICIDIAL_SRC_DIR}/www" /var/www/html/vicidial

# -----------------------------------------------------------------------------
# Completion
# -----------------------------------------------------------------------------
log_success "Stage 05 completed – Vicidial core installed successfully"

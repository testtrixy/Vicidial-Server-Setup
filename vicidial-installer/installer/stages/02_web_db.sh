#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Stage 02 – Web & Database (EL9 – Golden)
# Purpose:
#   - Install and configure MariaDB 10.11 (EL9 AppStream)
#   - Install Perl DB stack (DBI + DBD::MariaDB)
#   - Create Vicidial databases and users
#   - Install PHP 7.4 (Remi) and Apache
#   - Perform authoritative DB preflight checks
###############################################################################

###############################################################################
# Bootstrap & Guards
###############################################################################


STAGE_NAME="Stage_02"
stage_begin "${STAGE_NAME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"




# Hard assert OS base completed
[[ -f /var/lib/vicidial-install/os_base_complete ]] \
  || fatal "OS base stage not completed"

# Hard assert MySQL forbidden
rpm -qa | grep -Eq 'mysql|community-mysql' \
  && fatal "MySQL packages detected — forbidden"




require_root
require_command dnf
require_command systemctl

log "=== Stage 02: Web & Database (EL9) ==="

# -----------------------------------------------------------------------------
# Reboot acknowledgement (Stage 01 dependency)
# -----------------------------------------------------------------------------
rm -f /var/lib/vicidial-install/reboot_required
require_rebooted_if_needed || true

###############################################################################
# OS Guard (Hard Fail if Not EL9)
###############################################################################
check_el9

###############################################################################
# MariaDB + Perl DB Stack Installation (EL9 AppStream)
###############################################################################

log "Installing MariaDB server and Perl DB stack (EL9)"

dnf install -y \
  MariaDB-server \
  MariaDB-backup \
  perl \
  perl-DBI \
  perl-DBD-MariaDB

###############################################################################
# Enable & Start MariaDB
###############################################################################

log "Enabling and starting MariaDB service"

systemctl daemon-reexec || true
systemctl enable --now mariadb

# Enforce TCP reachability (no socket ambiguity)
mysql -h 127.0.0.1 -P 3306 -e "SELECT 1" \
  || fatal "MariaDB not reachable via TCP"
  

###############################################################################
# Apply Vicidial MariaDB Configuration
###############################################################################

VICIDIAL_CNF="/etc/my.cnf.d/vicidial.cnf"

if [[ ! -f "${VICIDIAL_CNF}" ]]; then
  log "Creating Vicidial MariaDB configuration"

  cat > "${VICIDIAL_CNF}" <<'EOF'
[mysqld]
# Vicidial compatibility (EL9)
sql_mode="NO_ENGINE_SUBSTITUTION"
default_storage_engine=MyISAM

# Performance tuning
key_buffer_size=512M
max_connections=2000
open_files_limit=24576

# Query cache (MariaDB still supports this)
query_cache_type=ON
query_cache_size=64M
query_cache_limit=2M
EOF
else
  log "Vicidial MariaDB configuration already exists – skipping"
fi

log "Restarting MariaDB to apply configuration"
systemctl restart mariadb

###############################################################################
# Secure MariaDB Baseline
###############################################################################

log "Applying MariaDB baseline security hardening"

mysql <<'EOF'
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db LIKE 'test%';
FLUSH PRIVILEGES;
EOF

###############################################################################
# Vicidial Databases & Users
###############################################################################

require_vars VICIDIAL_DB_NAME VICIDIAL_DB_USER VICIDIAL_DB_PASS

log "Creating Vicidial databases and users"

mysql <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8;
CREATE DATABASE IF NOT EXISTS ${VICIDIAL_DB_NAME} CHARACTER SET utf8;

CREATE USER IF NOT EXISTS '${VICIDIAL_DB_USER}'@'localhost'
  IDENTIFIED BY '${VICIDIAL_DB_PASS}';

CREATE USER IF NOT EXISTS '${VICIDIAL_DB_USER}'@'%'
  IDENTIFIED BY '${VICIDIAL_DB_PASS}';

GRANT ALL PRIVILEGES ON asterisk.* TO '${VICIDIAL_DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON asterisk.* TO '${VICIDIAL_DB_USER}'@'%';

GRANT ALL PRIVILEGES ON ${VICIDIAL_DB_NAME}.* TO '${VICIDIAL_DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${VICIDIAL_DB_NAME}.* TO '${VICIDIAL_DB_USER}'@'%';

FLUSH PRIVILEGES;
EOF

###############################################################################
# PHP 7.4 via Remi (EL9)
###############################################################################

require_vars PHP_VERSION

log "Installing PHP ${PHP_VERSION} via Remi repository"

dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
dnf module reset php -y
dnf module enable php:remi-${PHP_VERSION} -y

dnf install -y \
  php php-cli php-common php-mysqlnd php-gd php-mbstring \
  php-imap php-xml php-pear php-process php-pdo

###############################################################################
# Apache HTTPD
###############################################################################

log "Installing Apache HTTPD"

dnf install -y httpd mod_ssl
systemctl enable --now httpd

###############################################################################
# Authoritative Database Preflight (EL9-Golden)
###############################################################################

log "Running authoritative EL9 database preflight checks"
db_preflight

###############################################################################
# Completion
###############################################################################

log "Stage 02 completed successfully (EL9-Golden)"
stage_finish "${STAGE_NAME}"





#!/usr/bin/env bash
# =============================================================================
# Stage 02 – Web & Database
# Responsibilities:
#   - MariaDB 10.11 (repo-based)
#   - Apache + PHP 7.4 (Remi)
#   - MySQL tuning via templates
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Safety
# -----------------------------------------------------------------------------
require_root
require_command dnf
require_command systemctl

log_info "Stage 02: Web & Database started"

# -----------------------------------------------------------------------------
# Reboot validation (Stage 01 dependency)
# -----------------------------------------------------------------------------

# commented it out
require_rebooted_if_needed
rm -f /var/lib/vicidial-install/reboot_required

# -----------------------------------------------------------------------------
# MariaDB Repository (Template-driven)
# -----------------------------------------------------------------------------
log_info "Stage 02 – Configuring MariaDB ${MARIADB_VERSION} repository"

render_template \
  "${INSTALLER_ROOT}/templates/mysql/mariadb.repo.tpl" \
  "/etc/yum.repos.d/mariadb.repo" \
  0644 root:root

dnf clean all

# -----------------------------------------------------------------------------
# Install MariaDB
# -----------------------------------------------------------------------------
log_info "Stage 02 – Installing MariaDB server"

dnf -y install mariadb-server mariadb-devel mariadb-backup

systemctl enable mariadb --now

# -----------------------------------------------------------------------------
# Secure MariaDB baseline
# -----------------------------------------------------------------------------
log_info "Stage 02 – Applying MariaDB baseline security"

mysql <<'EOF'
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db LIKE 'test%';
FLUSH PRIVILEGES;
EOF

# -----------------------------------------------------------------------------
# Render MySQL tuning
# -----------------------------------------------------------------------------
require_vars MYSQL_BIND_ADDRESS MYSQL_MAX_CONNECTIONS MYSQL_INNODB_BUFFER_POOL

render_template \
  "${INSTALLER_ROOT}/templates/mysql/vicidial.cnf.tpl" \
  "/etc/my.cnf.d/vicidial.cnf" \
  0644 root:root

systemctl restart mariadb

# -----------------------------------------------------------------------------
# Create Vicidial databases & user
# -----------------------------------------------------------------------------
log_info "Creating Vicidial databases and user"

mysql <<EOF
CREATE DATABASE IF NOT EXISTS asterisk CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS vicidial CHARACTER SET utf8mb4;

CREATE USER IF NOT EXISTS '${VICIDIAL_DB_USER}'@'localhost'
  IDENTIFIED BY '${VICIDIAL_DB_PASS}';

GRANT ALL PRIVILEGES ON asterisk.* TO '${VICIDIAL_DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON vicidial.* TO '${VICIDIAL_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# -----------------------------------------------------------------------------
# PHP 7.4 via Remi (Vicidial requirement)
# -----------------------------------------------------------------------------
log_info "Installing PHP ${PHP_VERSION} via Remi"

dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm
dnf module reset php -y
dnf module enable php:remi-${PHP_VERSION} -y

dnf -y install \
  php php-cli php-common php-mysqlnd php-gd php-mbstring \
  php-imap php-xml php-pear php-process php-pdo

# -----------------------------------------------------------------------------
# Apache
# -----------------------------------------------------------------------------
log_info "Installing Apache"

dnf -y install httpd mod_ssl
systemctl enable httpd --now

log_success "Stage 02 completed successfully"

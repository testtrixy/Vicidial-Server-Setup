#!/usr/bin/env bash
set -euo pipefail

require_root
require_command dnf
require_command systemctl

log_info "Stage 02: Web & Database started"

# -----------------------------------------------------------------------------
# Reboot acknowledgement (Stage 01 dependency)
# -----------------------------------------------------------------------------
# Stage 02 ACKNOWLEDGES the reboot boundary
rm -f /var/lib/vicidial-install/reboot_required

# Enforce reboot sanity (SELinux permissive is acceptable here)
require_rebooted_if_needed || true

# -----------------------------------------------------------------------------
# MariaDB Repository (Template-driven)
# -----------------------------------------------------------------------------
log_info "Configuring MariaDB ${MARIADB_VERSION} repository"

render_template \
  "${INSTALLER_ROOT}/templates/mysql/mariadb.repo.tpl" \
  "/etc/yum.repos.d/mariadb.repo" \
  0644 root:root

dnf clean all

# -----------------------------------------------------------------------------
# MariaDB installation (Upstream only)
# -----------------------------------------------------------------------------
log_info "Disabling distribution MariaDB module"
dnf -y module disable mariadb || true

log_info "Removing conflicting distro MariaDB/MySQL packages (if any)"
dnf -y remove mariadb\* mysql\* || true

dnf clean all

log_info "Installing MariaDB ${MARIADB_VERSION} from upstream repo"
dnf -y install \
  MariaDB-server \
  MariaDB-client \
  MariaDB-backup \
  MariaDB-devel

log_info "Enabling MariaDB service"
systemctl enable mariadb --now

# -----------------------------------------------------------------------------
# Secure MariaDB baseline
# -----------------------------------------------------------------------------
log_info "Applying MariaDB baseline security"

mysql <<'EOF'
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db LIKE 'test%';
FLUSH PRIVILEGES;
EOF

# -----------------------------------------------------------------------------
# MySQL tuning
# -----------------------------------------------------------------------------
require_vars MYSQL_BIND_ADDRESS MYSQL_MAX_CONNECTIONS MYSQL_INNODB_BUFFER_POOL

render_template \
  "${INSTALLER_ROOT}/templates/mysql/vicidial.cnf.tpl" \
  "/etc/my.cnf.d/vicidial.cnf" \
  0644 root:root

systemctl restart mariadb

# -----------------------------------------------------------------------------
# Vicidial databases & user
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
# PHP 7.4 via Remi
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

# # /etc/dnf/dnf.conf
#block MySQL packages globally
dnf -y remove mysql-libs mysql-common 2>/dev/null || true
exclude=mysql* community-mysql*


log_info "Installing Apache"

dnf -y install httpd mod_ssl
systemctl enable httpd --now

log_success "Stage 02 completed successfully"

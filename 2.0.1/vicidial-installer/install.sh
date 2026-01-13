#!/usr/bin/env bash
#!/usr/bin/env bash
set -e

BASE="$(cd "$(dirname "$0")" && pwd)"

source $BASE/config/installer.conf
source $BASE/lib/logger.sh
source $BASE/lib/preflight.sh
source $BASE/lib/common.sh

log "=== VICIDIAL INSTALL START ==="
preflight

run os/base.sh
run os/packages.sh

run asterisk/build.sh
run asterisk/configure.sh

run vicidial/install.sh
run vicidial/database.sh

run security/apache-hardening.sh
run security/php-hardening.sh
run security/mariadb-hardening.sh
run security/firewall.sh
run security/selinux.sh
run security/permissions.sh

run security/https.sh
run security/force-https.sh
run security/php-hardening.sh
run security/apache-hardening.sh



run health/healthcheck.sh

log "=== INSTALL COMPLETE ==="

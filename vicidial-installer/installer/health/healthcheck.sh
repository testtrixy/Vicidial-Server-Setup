#!/usr/bin/env bash
# =============================================================================
# Vicidial 2026 – Health Check (Enhanced)
#
# SAFE:
#   - Read-only
#   - No service restarts
#   - No mutations
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Bootstrap
# -----------------------------------------------------------------------------
INSTALLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${INSTALLER_ROOT}/lib/common.sh"
source "${INSTALLER_ROOT}/config/versions.env"
source "${INSTALLER_ROOT}/config/paths.env"
source "${INSTALLER_ROOT}/config/secrets.env" 2>/dev/null || true
source "${INSTALLER_ROOT}/config/features.env" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Color support (TTY only)
# -----------------------------------------------------------------------------
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  NC='\033[0m'
else
  RED='' ; GREEN='' ; YELLOW='' ; NC=''
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo -e "[ ${GREEN}PASS${NC} ] $1"; ((PASS_COUNT++)); }
fail() { echo -e "[ ${RED}FAIL${NC} ] $1"; ((FAIL_COUNT++)); }
warn() { echo -e "[ ${YELLOW}WARN${NC} ] $1"; ((WARN_COUNT++)); }

echo "===================================================="
echo " Vicidial 2026 – System Health Check"
echo "===================================================="

# -----------------------------------------------------------------------------
# 1. OS & Kernel
# -----------------------------------------------------------------------------
echo
echo "▶ OS & Kernel"

if grep -qE 'Rocky|Alma' /etc/os-release; then
  pass "Supported OS detected (EL9)"
else
  fail "Unsupported OS (Rocky/Alma EL9 required)"
fi

if command -v getenforce >/dev/null 2>&1; then
  if [[ "$(getenforce)" == "Disabled" ]]; then
    pass "SELinux disabled"
  else
    warn "SELinux not disabled (may affect Vicidial)"
  fi
else
  warn "SELinux tools not found"
fi

# -----------------------------------------------------------------------------
# 2. Time Sync
# -----------------------------------------------------------------------------
echo
echo "▶ Time Synchronization"

if timedatectl show | grep -q "NTPSynchronized=yes"; then
  pass "System clock synchronized (NTP)"
else
  warn "Clock not synchronized (chrony issue?)"
fi

# -----------------------------------------------------------------------------
# 3. Database
# -----------------------------------------------------------------------------
echo
echo "▶ Database (MariaDB)"

if systemctl is-active --quiet mariadb; then
  pass "MariaDB service running"
else
  fail "MariaDB service not running"
fi

if mysqladmin ping >/dev/null 2>&1; then
  pass "MariaDB responding to queries"
else
  fail "MariaDB not responding"
fi

# Vicidial schema sanity (WARN-only)
if mysql -N -e "SHOW TABLES LIKE 'vicidial_users';" asterisk 2>/dev/null | grep -q vicidial_users; then
  USER_COUNT=$(mysql -N -e "SELECT COUNT(*) FROM vicidial_users;" asterisk 2>/dev/null || echo 0)
  if [[ "${USER_COUNT}" -gt 0 ]]; then
    pass "Vicidial users table populated (${USER_COUNT} users)"
  else
    warn "Vicidial users table exists but is empty"
  fi
else
  fail "asterisk schema missing (vicidial_users table not found)"
fi

# -----------------------------------------------------------------------------
# 4. Asterisk
# -----------------------------------------------------------------------------
echo
echo "▶ Asterisk"

if systemctl is-active --quiet asterisk; then
  pass "Asterisk service running"
else
  fail "Asterisk service not running"
fi

if asterisk -rx "core show uptime" >/dev/null 2>&1; then
  pass "Asterisk CLI responsive"
else
  fail "Asterisk CLI not responding"
fi

# -----------------------------------------------------------------------------
# 5. Vicidial Core
# -----------------------------------------------------------------------------
echo
echo "▶ Vicidial Core"

VICIDIAL_HOME="/usr/share/astguiclient"

if [[ -d "${VICIDIAL_HOME}" ]]; then
  pass "Vicidial directory present"
else
  fail "Vicidial directory missing"
fi

for f in AST_manager_send.pl AST_VDauto_dial.pl ADMIN_keepalive_ALL.pl; do
  if [[ -f "${VICIDIAL_HOME}/${f}" ]]; then
    pass "Vicidial script present: ${f}"
  else
    fail "Missing Vicidial script: ${f}"
  fi
done

if [[ -f /etc/astguiclient.conf ]]; then
  pass "/etc/astguiclient.conf present"
else
  fail "/etc/astguiclient.conf missing"
fi

# -----------------------------------------------------------------------------
# 6. Cron Jobs
# -----------------------------------------------------------------------------
echo
echo "▶ Cron Jobs"

CRONTAB="$(crontab -l 2>/dev/null || true)"

for job in ADMIN_keepalive_ALL.pl AST_manager_send.pl AST_VDauto_dial.pl; do
  if echo "${CRONTAB}" | grep -q "${job}"; then
    pass "Cron job installed: ${job}"
  else
    fail "Cron job missing: ${job}"
  fi
done

# -----------------------------------------------------------------------------
# 7. AMI (Asterisk Manager Interface)
# -----------------------------------------------------------------------------
echo
echo "▶ Asterisk Manager Interface (AMI)"

if grep -q "bindaddr = 127.0.0.1" /etc/asterisk/manager.conf 2>/dev/null; then
  pass "AMI bound to localhost"
else
  warn "AMI not restricted to localhost"
fi

if grep -q "^\[cron\]" /etc/asterisk/manager.conf 2>/dev/null; then
  pass "AMI cron user configured"
else
  fail "AMI cron user missing"
fi

# -----------------------------------------------------------------------------
# 8. Web Stack
# -----------------------------------------------------------------------------
echo
echo "▶ Web Stack"

if systemctl is-active --quiet httpd; then
  pass "Apache is running"
else
  fail "Apache not running"
fi

if php -v 2>/dev/null | grep -q "PHP ${PHP_VERSION}"; then
  pass "PHP version matches pinned version (${PHP_VERSION})"
else
  fail "PHP version mismatch (expected ${PHP_VERSION})"
fi

# -----------------------------------------------------------------------------
# 9. Audio & Sounds
# -----------------------------------------------------------------------------
echo
echo "▶ Audio & Sounds"

if [[ -d /var/lib/asterisk/sounds/en ]]; then
  pass "Asterisk English sound files present"
else
  fail "Asterisk sound files missing"
fi

if [[ -d /var/lib/asterisk/moh ]]; then
  pass "Music On Hold directory present"
else
  warn "MOH directory missing"
fi

# -----------------------------------------------------------------------------
# 10. Optional Features (Stage 08)
# -----------------------------------------------------------------------------
echo
echo "▶ Optional Features"

if [[ "${ENABLE_HTTPS:-no}" == "yes" ]]; then
  if [[ -d /etc/letsencrypt ]]; then
    pass "HTTPS enabled & certificates present"
  else
    warn "HTTPS enabled but certificates missing"
  fi
else
  echo "[INFO] HTTPS not enabled (expected)"
fi

if [[ "${ENABLE_MONITORING_HOOKS:-no}" == "yes" ]]; then
  if systemctl is-active --quiet node_exporter; then
    pass "Monitoring exporter running"
  else
    warn "Monitoring enabled but exporter not running"
  fi
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo
echo "===================================================="
echo " Health Check Summary"
echo "===================================================="
echo " PASSED : ${PASS_COUNT}"
echo " WARN   : ${WARN_COUNT}"
echo " FAILED : ${FAIL_COUNT}"
echo "===================================================="

if [[ "${FAIL_COUNT}" -gt 0 ]]; then
  echo -e "${RED}❌ SYSTEM HEALTH: FAIL${NC}"
  exit 1
else
  echo -e "${GREEN}✅ SYSTEM HEALTH: PASS${NC}"
  exit 0
fi

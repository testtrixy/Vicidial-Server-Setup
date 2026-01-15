#!/usr/bin/env bash
# =============================================================================
# Vicidial 2026 – Health Check & Validation
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Counters (MUST start at 0)
# -----------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# -----------------------------------------------------------------------------
# Result helpers (SAFE with set -e)
# -----------------------------------------------------------------------------
pass() {
  echo -e "[ ${GREEN}PASS${NC} ] $1"
  ((PASS_COUNT++)) || true
}

fail() {
  echo -e "[ ${RED}FAIL${NC} ] $1"
  ((FAIL_COUNT++)) || true
}

warn() {
  echo -e "[ ${YELLOW}WARN${NC} ] $1"
  ((WARN_COUNT++)) || true
}

section() {
  echo -e "\n${BLUE}▶ $1${NC}"
}

# -----------------------------------------------------------------------------
# Header
# -----------------------------------------------------------------------------
echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE} Vicidial 2026 – System Health Check${NC}"
echo -e "${BLUE}====================================================${NC}"

# -----------------------------------------------------------------------------
# OS & Kernel
# -----------------------------------------------------------------------------
section "OS & Kernel"

if grep -qE "rocky|almalinux|rhel" /etc/os-release; then
  pass "Supported OS detected (EL9)"
else
  fail "Unsupported OS"
fi

if [[ "$(getenforce 2>/dev/null || echo Disabled)" != "Enforcing" ]]; then
  pass "SELinux not enforcing"
else
  fail "SELinux enforcing"
fi

# -----------------------------------------------------------------------------
# Time Sync
# -----------------------------------------------------------------------------
section "Time Synchronization"

if command -v timedatectl >/dev/null && timedatectl show | grep -q NTPSynchronized=yes; then
  pass "System clock synchronized (NTP)"
else
  warn "NTP not synchronized"
fi

# -----------------------------------------------------------------------------
# Database (MariaDB)
# -----------------------------------------------------------------------------
section "Database (MariaDB)"

if systemctl is-active --quiet mariadb; then
  pass "MariaDB service running"
else
  fail "MariaDB service NOT running"
fi

if mysqladmin ping >/dev/null 2>&1; then
  pass "MariaDB responding to queries"
else
  fail "MariaDB not responding"
fi

if mysql -N -e "SHOW DATABASES LIKE 'asterisk';" | grep -q asterisk; then
  pass "Vicidial database (asterisk) exists"
else
  fail "Vicidial database missing"
fi

# -----------------------------------------------------------------------------
# Asterisk
# -----------------------------------------------------------------------------
section "Asterisk Telephony"

if systemctl is-active --quiet asterisk; then
  pass "Asterisk service running"
else
  fail "Asterisk service NOT running"
fi

if [[ -S /var/run/asterisk/asterisk.ctl ]]; then
  pass "Asterisk control socket present"
else
  warn "Asterisk control socket missing"
fi

if command -v asterisk >/dev/null && asterisk -rx "core show uptime" >/dev/null 2>&1; then
  pass "Asterisk responding to CLI"
else
  warn "Asterisk CLI not responding"
fi

# -----------------------------------------------------------------------------
# Vicidial Core
# -----------------------------------------------------------------------------
section "Vicidial Core"

if [[ -f /etc/astguiclient.conf ]]; then
  pass "astguiclient.conf exists"
else
  fail "astguiclient.conf missing"
fi

if [[ -d /usr/share/astguiclient ]]; then
  pass "Vicidial scripts directory present"
else
  fail "Vicidial scripts directory missing"
fi

# -----------------------------------------------------------------------------
# Perl Environment
# -----------------------------------------------------------------------------
section "Perl Environment"

if perl -MDBD::mysql -e 1 >/dev/null 2>&1; then
  pass "DBD::mysql Perl driver available"
else
  fail "DBD::mysql Perl driver missing"
fi

# -----------------------------------------------------------------------------
# Web Stack
# -----------------------------------------------------------------------------
section "Web Stack"

if systemctl is-active --quiet httpd; then
  pass "Apache (httpd) running"
else
  fail "Apache NOT running"
fi

if [[ -d /var/www/html/vicidial ]]; then
  pass "Vicidial web directory present"
else
  fail "Vicidial web directory missing"
fi

# -----------------------------------------------------------------------------
# Audio / MOH
# -----------------------------------------------------------------------------
section "Audio & MOH"

if [[ -d /var/lib/asterisk/moh ]]; then
  pass "Music On Hold directory exists"
else
  warn "MOH directory missing"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}====================================================${NC}"
echo -e "${BLUE} Health Check Summary${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e " PASSED : ${GREEN}${PASS_COUNT}${NC}"
echo -e " WARN   : ${YELLOW}${WARN_COUNT}${NC}"
echo -e " FAILED : ${RED}${FAIL_COUNT}${NC}"
echo -e "${BLUE}====================================================${NC}"

if [[ "${FAIL_COUNT}" -eq 0 ]]; then
  echo -e "${GREEN}✅ SYSTEM HEALTH: PASS${NC}"
  exit 0
else
  echo -e "${RED}❌ SYSTEM HEALTH: FAIL${NC}"
  exit 1
fi

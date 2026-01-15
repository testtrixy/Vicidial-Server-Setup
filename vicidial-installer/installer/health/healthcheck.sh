#!/usr/bin/env bash
# =============================================================================
# Vicidial EL9 – Health Check & Validation (Role-Aware)
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
# Counters
# -----------------------------------------------------------------------------
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# -----------------------------------------------------------------------------
# Result helpers
# -----------------------------------------------------------------------------
pass() { echo -e "[ ${GREEN}PASS${NC} ] $1"; ((PASS_COUNT++)) || true; }
fail() { echo -e "[ ${RED}FAIL${NC} ] $1"; ((FAIL_COUNT++)) || true; }
warn() { echo -e "[ ${YELLOW}WARN${NC} ] $1"; ((WARN_COUNT++)) || true; }

section() {
  echo -e "\n${BLUE}▶ $1${NC}"
}

# -----------------------------------------------------------------------------
# Header
# -----------------------------------------------------------------------------
echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE} Vicidial EL9 – System Health Check${NC}"
echo -e "${BLUE}====================================================${NC}"

# -----------------------------------------------------------------------------
# OS & SELinux
# -----------------------------------------------------------------------------
section "OS & SELinux"

if grep -qE "rocky|almalinux|rhel" /etc/os-release; then
  pass "Supported EL9 OS detected"
else
  fail "Unsupported OS"
fi

SELINUX_STATE="$(getenforce 2>/dev/null || echo Disabled)"
case "${SELINUX_STATE}" in
  Enforcing) pass "SELinux Enforcing (correct)" ;;
  Permissive) warn "SELinux Permissive" ;;
  Disabled) warn "SELinux Disabled" ;;
  *) warn "SELinux state unknown" ;;
esac

# -----------------------------------------------------------------------------
# Time Sync
# -----------------------------------------------------------------------------
section "Time Synchronization"

if command -v timedatectl >/dev/null &&
   timedatectl show | grep -q NTPSynchronized=yes; then
  pass "System clock synchronized (NTP)"
else
  warn "NTP not synchronized"
fi

# -----------------------------------------------------------------------------
# Database (Role-Aware)
# -----------------------------------------------------------------------------
section "Database (MariaDB)"

if systemctl list-unit-files | grep -q '^mariadb\.service'; then
  if systemctl is-active --quiet mariadb; then
    pass "MariaDB service running"
  else
    fail "MariaDB installed but NOT running"
  fi
else
  warn "MariaDB server not installed (expected on non-DB nodes)"
fi

# DBI connectivity (authoritative)
if [[ -f /etc/astguiclient.conf ]]; then
  if perl -MDBI -MDBD::MariaDB -e 'exit' 2>/dev/null; then
    pass "Perl DBI + DBD::MariaDB available"
  else
    fail "Perl DBI / DBD::MariaDB missing"
  fi
else
  warn "astguiclient.conf missing (Stage 05 not run)"
fi

# -----------------------------------------------------------------------------
# Asterisk
# -----------------------------------------------------------------------------
section "Asterisk Telephony"

if systemctl list-unit-files | grep -q '^asterisk\.service'; then
  if systemctl is-active --quiet asterisk; then
    pass "Asterisk service running"
  else
    fail "Asterisk installed but NOT running"
  fi
else
  warn "Asterisk not installed (expected on DB/Web nodes)"
fi

if [[ -S /var/run/asterisk/asterisk.ctl ]]; then
  pass "Asterisk control socket present"
else
  warn "Asterisk control socket missing"
fi

# -----------------------------------------------------------------------------
# Vicidial Core
# -----------------------------------------------------------------------------
section "Vicidial Core"

[[ -f /etc/astguiclient.conf ]] \
  && pass "astguiclient.conf present" \
  || fail "astguiclient.conf missing"

[[ -d /usr/share/astguiclient ]] \
  && pass "Vicidial core directory present" \
  || fail "Vicidial core directory missing"

# -----------------------------------------------------------------------------
# Web Stack
# -----------------------------------------------------------------------------
section "Web Stack"

if systemctl list-unit-files | grep -q '^httpd\.service'; then
  if systemctl is-active --quiet httpd; then
    pass "Apache (httpd) running"
  else
    fail "Apache installed but NOT running"
  fi
else
  warn "Apache not installed (expected on DB/telephony nodes)"
fi

[[ -d /var/www/html/vicidial ]] \
  && pass "Vicidial web directory present" \
  || warn "Vicidial web directory missing"

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

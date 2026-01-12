#!/usr/bin/env bash
# ------------------------------------------------------------
# 99-verify.sh — VICIdial Full System Health Check
# Purpose: One-command verification of a VICIdial installation
# ------------------------------------------------------------

set -euo pipefail

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
NC="\e[0m"

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; EXIT_CODE=1; }

EXIT_CODE=0

banner() {
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

banner "VICIdial 99-verify.sh — System Health Check"

# ------------------------------------------------------------
# 1. OS & SELinux
# ------------------------------------------------------------
banner "OS & SELinux"
if command -v getenforce >/dev/null 2>&1; then
  SEL=$(getenforce)
  if [[ "$SEL" == "Enforcing" ]]; then
    warn "SELinux is Enforcing (ensure contexts are set)"
  else
    ok "SELinux mode: $SEL"
  fi
else
  warn "SELinux not installed"
fi

# ------------------------------------------------------------
# 2. Apache / HTTP
# ------------------------------------------------------------
banner "Apache / HTTP"
if systemctl is-active --quiet httpd; then
  ok "Apache (httpd) is running"
else
  fail "Apache (httpd) is NOT running"
fi

if ss -lnt | grep -q ':80 '; then
  ok "Port 80 is listening"
else
  fail "Port 80 not listening"
fi

# ------------------------------------------------------------
# 3. PHP Runtime & Modules
# ------------------------------------------------------------
banner "PHP"
if command -v php >/dev/null 2>&1; then
  ok "PHP present: $(php -v | head -n1)"
else
  fail "PHP not installed"
fi

REQUIRED_PHP_MODULES=(mysqlnd mbstring xml gd)
for mod in "${REQUIRED_PHP_MODULES[@]}"; do
  if php -m | grep -qi "^$mod$"; then
    ok "PHP module loaded: $mod"
  else
    fail "Missing PHP module: $mod"
  fi
done

# ------------------------------------------------------------
# 4. MariaDB / MySQL
# ------------------------------------------------------------
banner "Database"
if systemctl is-active --quiet mariadb; then
  ok "MariaDB is running"
else
  fail "MariaDB is NOT running"
fi

if [[ -f /etc/astguiclient.conf ]]; then
  DB_USER=$(grep '^VARDB_user=' /etc/astguiclient.conf | cut -d= -f2)
  DB_PASS=$(grep '^VARDB_pass=' /etc/astguiclient.conf | cut -d= -f2)
  DB_NAME=$(grep '^VARDB_database=' /etc/astguiclient.conf | cut -d= -f2)

  if mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e 'SHOW TABLES;' >/dev/null 2>&1; then
    ok "DB credentials valid for database '$DB_NAME'"
  else
    fail "DB login failed using astguiclient.conf credentials"
  fi
else
  fail "/etc/astguiclient.conf not found"
fi

# ------------------------------------------------------------
# 5. Perl & CPAN Modules
# ------------------------------------------------------------
banner "Perl / CPAN"
if command -v perl >/dev/null 2>&1; then
  ok "Perl present: $(perl -v | head -n2 | tail -n1)"
else
  fail "Perl not installed"
fi

REQUIRED_PERL_MODULES=(DBI DBD::mysql Net::Server Time::HiRes Unicode::Map Jcode Spreadsheet::WriteExcel Mail::Sendmail)
for pm in "${REQUIRED_PERL_MODULES[@]}"; do
  if perl -M"$pm" -e1 >/dev/null 2>&1; then
    ok "Perl module available: $pm"
  else
    fail "Missing Perl module: $pm"
  fi
done

# ------------------------------------------------------------
# 6. DAHDI Timing
# ------------------------------------------------------------
banner "DAHDI Timing"
if command -v dahdi_cfg >/dev/null 2>&1; then
  if dahdi_cfg -t >/dev/null 2>&1; then
    ok "DAHDI timing source active"
  else
    fail "DAHDI installed but timing source not active"
  fi
else
  fail "DAHDI tools not installed"
fi

# ------------------------------------------------------------
# 7. VICIdial Runtime (Screen & Cron)
# ------------------------------------------------------------
banner "VICIdial Runtime"

if command -v screen >/dev/null 2>&1; then
  SCREENS=$(screen -ls | grep -c 'Detached' || true)
  if [[ "$SCREENS" -ge 1 ]]; then
    ok "Screen sessions detected ($SCREENS)"
  else
    fail "No VICIdial screen sessions running"
  fi
else
  fail "screen not installed"
fi

if crontab -l >/dev/null 2>&1; then
  ok "Crontab accessible"
else
  fail "Crontab not accessible"
fi

# ------------------------------------------------------------
# Final Status
# ------------------------------------------------------------
banner "Final Status"
if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo -e "${GREEN}VICIdial system health: PASS${NC}"
else
  echo -e "${RED}VICIdial system health: FAIL (review output above)${NC}"
fi

exit "$EXIT_CODE"
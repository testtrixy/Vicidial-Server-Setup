#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo " VICIdial EL9 – System Sanity & Health Check"
echo "============================================================"

FAIL=0

pass() { echo "✅ PASS: $1"; }
fail() { echo "❌ FAIL: $1"; FAIL=1; }

# -----------------------------------------------------------------------------
# 1. Database Connectivity (MariaDB via TCP, cron user)
# -----------------------------------------------------------------------------
echo
echo "[1/8] Database connectivity (MariaDB, TCP, cron user)"

if mysql -h 127.0.0.1 -u cron -p"${VICIDIAL_DB_PASS:-1234}" \
  -e "SELECT 1;" >/dev/null 2>&1; then
  pass "MariaDB reachable via TCP as cron user"
else
  fail "MariaDB connection failed (cron user / TCP)"
fi

# -----------------------------------------------------------------------------
# 2. Perl DBI Driver (MariaDB)
# -----------------------------------------------------------------------------
echo
echo "[2/8] Perl DBI driver check (MariaDB)"

if perl -MDBI -e 'exit(DBI->available_drivers =~ /MariaDB/ ? 0 : 1)'; then
  pass "Perl DBI MariaDB driver available"
else
  fail "Perl DBI MariaDB driver missing"
fi

# -----------------------------------------------------------------------------
# 3. Asterisk Runtime
# -----------------------------------------------------------------------------
echo
echo "[3/8] Asterisk runtime"

if asterisk -rx "core show uptime" >/dev/null 2>&1; then
  pass "Asterisk running and responding"
else
  fail "Asterisk not running or not responding"
fi

# -----------------------------------------------------------------------------
# 4. Legacy SIP (chan_sip – REQUIRED by VICIdial)
# -----------------------------------------------------------------------------
echo
echo "[4/8] Legacy SIP (chan_sip)"

if asterisk -rx "sip show peers" >/dev/null 2>&1; then
  pass "chan_sip loaded and responding"
else
  fail "chan_sip missing or not responding"
fi

# -----------------------------------------------------------------------------
# 5. AMI Enabled
# -----------------------------------------------------------------------------
echo
echo "[5/8] Asterisk Manager Interface (AMI)"

if asterisk -rx "manager show settings" | grep -q "Manager (AMI): *Yes"; then
  pass "AMI enabled"
else
  fail "AMI not enabled"
fi

# -----------------------------------------------------------------------------
# 6. VICIdial AMI Listener (systemd)
# -----------------------------------------------------------------------------
echo
echo "[6/8] VICIdial AMI listener service"

if systemctl is-active --quiet vicidial-ami-listener; then
  pass "vicidial-ami-listener service running"
else
  fail "vicidial-ami-listener service NOT running"
fi

# -----------------------------------------------------------------------------
# 7. VICIdial Backend Scripts (non-blocking)
# -----------------------------------------------------------------------------
echo
echo "[7/8] VICIdial backend script execution"

if timeout 15 /usr/share/astguiclient/AST_update.pl >/dev/null 2>&1; then
  pass "AST_update.pl executed successfully"
else
  fail "AST_update.pl failed or timed out"
fi

if timeout 10 /usr/share/astguiclient/AST_manager_send.pl >/dev/null 2>&1; then
  pass "AST_manager_send.pl executed successfully"
else
  fail "AST_manager_send.pl failed (listener issue?)"
fi

# -----------------------------------------------------------------------------
# 8. Logs & Cron Presence
# -----------------------------------------------------------------------------
echo
echo "[8/8] Cron jobs & log activity"

if ls /etc/cron.d | grep -q vicidial; then
  pass "VICIdial cron configuration present"
else
  fail "VICIdial cron configuration missing"
fi

if ls -ltr /var/log/astguiclient >/dev/null 2>&1; then
  pass "VICIdial logs directory present"
else
  fail "VICIdial logs directory missing"
fi

# -----------------------------------------------------------------------------
# Final Result
# -----------------------------------------------------------------------------
echo
echo "============================================================"

if [[ "$FAIL" -eq 0 ]]; then
  echo "🎉 SYSTEM STATUS: HEALTHY (E2E PASSED)"
  exit 0
else
  echo "🚨 SYSTEM STATUS: UNHEALTHY (SEE FAILURES ABOVE)"
  exit 1
fi

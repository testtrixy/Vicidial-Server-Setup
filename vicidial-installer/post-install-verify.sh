#!/bin/bash
echo "=== POST INSTALL VERIFICATION ==="

fail() { echo "[FAIL] $1"; exit 1; }

systemctl is-active --quiet asterisk || fail "Asterisk not running"
systemctl is-active --quiet mariadb || fail "MariaDB not running"
systemctl is-active --quiet httpd || fail "Apache not running"

lsmod | grep -q dahdi || fail "DAHDI not loaded"

asterisk -rx "core show uptime" >/dev/null || fail "Asterisk CLI not responding"

mysql -u "$DB_USER_CRON" -p"$DB_PASS_CRON" "$DB_NAME" \
  -e "select count(*) from vicidial_campaigns;" >/dev/null \
  || fail "VICIdial DB schema missing"

curl -sf http://localhost/vicidial/admin.php >/dev/null \
  || fail "VICIdial admin UI not reachable"



crontab -l | grep -q "VICIDIAL CRON START" \
  || { echo "[FAIL] VICIdial cron not installed"; exit 1; }
  

crontab -l | grep -q AST_CRON_audio || fail "VICIdial cron missing"

echo "[OK] POST INSTALL VERIFIED – SYSTEM READY"

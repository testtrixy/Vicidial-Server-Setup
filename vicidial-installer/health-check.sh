#!/bin/bash

echo "=== VICIDIAL HEALTH CHECK ==="

check() {
  systemctl is-active --quiet "$1" \
    && echo "[OK] $1 running" \
    || echo "[FAIL] $1 not running"
}

check mariadb
check httpd
check asterisk
check rc-local

crontab -l | grep AST_CRON_audio || echo "[WARN] VICIdial cron missing"

lsmod | grep -q dahdi && echo "[OK] DAHDI loaded" || echo "[FAIL] DAHDI missing"

df -h /var/spool/asterisk | awk 'NR==2 {print "Disk:", $5}'


mysql -u "$DB_USER_CRON" -p"$DB_PASS_CRON" "$DB_NAME" -e "show tables;" \
  >/dev/null && echo "[OK] DB accessible" || echo "[FAIL] DB access"
  





asterisk -rx "core show uptime" >/dev/null \
  && echo "[OK] Asterisk CLI" \
  || echo "[FAIL] Asterisk CLI"

curl -sf http://localhost/vicidial/admin.php >/dev/null \
  && echo "[OK] Web UI reachable" \
  || echo "[FAIL] Web UI not reachable"

echo "=== HEALTH CHECK DONE ==="



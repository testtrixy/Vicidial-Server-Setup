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
echo "[OK] DAHDI not required on Rocky 8"


df -h /var/spool/asterisk | awk 'NR==2 {print "Disk:", $5}'




echo "=== VICIDIAL HEALTH CHECK Start ==="

systemctl is-active --quiet mariadb \
  && echo "[OK] mariadb running" \
  || echo "[FAIL] mariadb not running"

systemctl is-active --quiet httpd \
  && echo "[OK] httpd running" \
  || echo "[FAIL] httpd not running"

systemctl is-active --quiet asterisk \
  && echo "[OK] asterisk running" \
  || echo "[FAIL] asterisk not running"

mysql -u root asterisk -e "SELECT 1;" >/dev/null 2>&1 \
  && echo "[OK] DB access" \
  || echo "[FAIL] DB access"

asterisk -rx "core show uptime" >/dev/null 2>&1 \
  && echo "[OK] Asterisk CLI" \
  || echo "[FAIL] Asterisk CLI"

curl -fs http://127.0.0.1/vicidial/admin.php >/dev/null \
  && echo "[OK] Web UI reachable" \
  || echo "[FAIL] Web UI not reachable"




echo "=== HEALTH CHECK DONE ==="






echo "=== HEALTH CHECK DONE ==="



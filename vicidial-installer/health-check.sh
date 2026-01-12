


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


systemctl is-active --quiet mariadb \
  && echo "[OK] mariadb running" \
  || echo "[FAIL] mariadb not running"

systemctl is-active --quiet httpd \
  && echo "[OK] httpd running" \
  || echo "[FAIL] httpd not running"

systemctl is-active --quiet asterisk \
  && echo "[OK] asterisk running" \
  || echo "[FAIL] asterisk not running"


mysql -u root asterisk -e "SELECT 1" &>/dev/null \
  && echo "[OK] DB access" || echo "[FAIL] DB access"

asterisk -rx "core show uptime" &>/dev/null \
  && echo "[OK] Asterisk CLI" || echo "[FAIL] Asterisk CLI"


  echo "[+] Checking VICIdial Web UI"

  HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" \
    http://127.0.0.1/vicidial/admin.php || echo "000")

  case "$HTTP_CODE" in
    200|401)
      echo "[OK] Web UI reachable (HTTP $HTTP_CODE)"
      ;;
    *)
      echo "[FAIL] Web UI unreachable (HTTP $HTTP_CODE)"
      ;;
  esac





echo "[INFO] DAHDI kernel modules not required on Rocky 8"


echo "=== HEALTH CHECK DONE ==="




#!/bin/bash
echo "=== POST INSTALL VERIFICATION ==="

fail() { echo "[FAIL] $1"; exit 1; }

systemctl is-active --quiet asterisk || fail "Asterisk not running"
systemctl is-active --quiet mariadb || fail "MariaDB not running"
systemctl is-active --quiet httpd || fail "Apache not running"

bash ./health-check-ami.sh




systemctl is-active --quiet fail2ban \
  || { echo "[FATAL] Fail2Ban not running"; exit 1; }

fail2ban-client status asterisk-sip >/dev/null \
  || { echo "[FATAL] SIP jail missing"; exit 1; }

fail2ban-client status asterisk-ami >/dev/null \
  || { echo "[FATAL] AMI jail missing"; exit 1; }






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



grep -q "enabled *= *yes" /etc/asterisk/manager.conf \
  || { echo "[FATAL] AMI not enabled"; exit 1; }

grep -q "$AMI_USER" /etc/asterisk/manager.conf \
  || { echo "[FATAL] AMI user missing"; exit 1; }


# Apache permissions check
grep -q 'AllowOverride All' /etc/httpd/conf/httpd.conf \
  || { echo "[FATAL] Apache AllowOverride not enabled"; exit 1; }

# PHP memory limit check
php -r 'echo ini_get("memory_limit");' | grep -q 512M \
  || { echo "[FATAL] PHP memory_limit not set"; exit 1; }



echo "[OK] POST INSTALL VERIFIED – SYSTEM READY"

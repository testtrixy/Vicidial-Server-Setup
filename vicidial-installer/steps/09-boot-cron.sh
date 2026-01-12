#!/bin/bash
set -euo pipefail



echo "=================================================="
echo " STEP 09: Services & Cron"
echo "=================================================="

systemctl enable mariadb httpd asterisk crond
systemctl start mariadb httpd crond
systemctl start asterisk
sleep 5

systemctl is-active --quiet asterisk || {
  echo "[FATAL] Asterisk failed to start"
  journalctl -u asterisk -n 50
  exit 1
}

CRON_TMP=$(mktemp)
crontab -l 2>/dev/null | sed '/VICIDIAL CRON START/,/VICIDIAL CRON END/d' > "$CRON_TMP"

cat <<'EOF' >> "$CRON_TMP"
# VICIDIAL CRON START
* * * * * /usr/share/astguiclient/ADMIN_keepalive_ALL.pl --cu3way
* * * * * /usr/share/astguiclient/AST_manager_kill_hung_congested.pl
* * * * * /usr/share/astguiclient/AST_VDhopper.pl -q
# VICIDIAL CRON END
EOF

crontab "$CRON_TMP"
rm -f "$CRON_TMP"

echo "[OK] Services running & cron installed"

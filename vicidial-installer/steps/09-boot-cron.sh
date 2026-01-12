#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " STEP 09: Boot, Services & VICIdial Cron Setup"
echo "=================================================="

# ---------------------------------------------------
# Preconditions
# ---------------------------------------------------
: "${DB_NAME:?DB_NAME must be set}"
: "${SERVER_IP:?SERVER_IP must be set}"

# ---------------------------------------------------
# Safe permission fixes (idempotent)
# ---------------------------------------------------
echo "[+] Fixing permissions"

if id asterisk &>/dev/null && [ -d /var/log/asterisk ]; then
  chown -R asterisk:asterisk /var/log/asterisk
fi

if [ -d /var/www/html/vicidial ]; then
  chown -R apache:apache /var/www/html/vicidial
fi

# ---------------------------------------------------
# Enable & start Asterisk (MANDATORY)
# ---------------------------------------------------
echo "[+] Enabling and starting Asterisk"

systemctl enable asterisk >/dev/null 2>&1 || true
systemctl start asterisk
sleep 5

if ! systemctl is-active --quiet asterisk; then
  echo "[FATAL] Asterisk failed to start"
  journalctl -u asterisk --no-pager -n 50
  exit 1
fi

echo "[OK] Asterisk running"

# ---------------------------------------------------
# Install VICIdial cron jobs (clean + idempotent)
# ---------------------------------------------------
echo "[+] Installing VICIdial cron jobs"

CRON_TMP="$(mktemp)"
crontab -l 2>/dev/null \
  | sed '/# VICIDIAL CRON START/,/# VICIDIAL CRON END/d' \
  > "$CRON_TMP" || true

cat <<'EOF' >> "$CRON_TMP"

# VICIDIAL CRON START
0,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57 * * * * /usr/share/astguiclient/AST_CRON_audio_1_move_mix.pl --MIX
0,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57 * * * * /usr/share/astguiclient/AST_CRON_audio_1_move_VDonly.pl
1,4,7,10,13,16,19,22,25,28,31,34,37,40,43,46,49,52,55,58 * * * * /usr/share/astguiclient/AST_CRON_audio_2_compress.pl --GSM

* * * * * /usr/share/astguiclient/ADMIN_keepalive_ALL.pl --cu3way
* * * * * /usr/share/astguiclient/AST_manager_kill_hung_congested.pl
* * * * * /usr/share/astguiclient/AST_vm_update.pl
* * * * * /usr/share/astguiclient/AST_conf_update.pl
11 * * * * /usr/share/astguiclient/AST_flush_DBqueue.pl -q
33 * * * * /usr/share/astguiclient/AST_cleanup_agent_log.pl
50 0 * * * /usr/share/astguiclient/AST_cleanup_agent_log.pl --last-24hours
* * * * * /usr/share/astguiclient/AST_VDhopper.pl -q
1 1,7 * * * /usr/share/astguiclient/ADMIN_adjust_GMTnow_on_leads.pl --debug
2 1 * * * /usr/share/astguiclient/AST_reset_mysql_vars.pl
3 1 * * * /usr/share/astguiclient/AST_DB_optimize.pl
30 * * * * /usr/sbin/ntpdate -u pool.ntp.org >/dev/null 2>&1
22 0 * * * /usr/share/astguiclient/AST_agent_day.pl
2 0 * * 0 /usr/share/astguiclient/AST_agent_week.pl
28 0 * * * /usr/bin/find /var/log/astguiclient -type f -mtime +2 -delete
29 0 * * * /usr/bin/find /var/log/asterisk -type f -mtime +2 -delete
* * * * * /usr/share/astguiclient/AST_inbound_email_parser.pl
# VICIDIAL CRON END

EOF

crontab "$CRON_TMP"
rm -f "$CRON_TMP"

echo "[OK] VICIdial cron installed"

# ---------------------------------------------------
# Post-install DB password rotation (optional script)
# ---------------------------------------------------
if [ -x ./post-install-db-rotate.sh ]; then
  echo "[+] Running DB password rotation"
  ./post-install-db-rotate.sh
fi

# ---------------------------------------------------
# rc.local compatibility (Rocky 8 safe)
# ---------------------------------------------------
echo "[+] Enabling rc.local compatibility"

chmod +x /etc/rc.d/rc.local

if [ ! -f /etc/systemd/system/rc-local.service ]; then
cat <<'EOF' > /etc/systemd/system/rc-local.service
[Unit]
Description=rc.local Compatibility
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.d/rc.local
TimeoutSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reexec
systemctl enable rc-local >/dev/null 2>&1 || true
systemctl start rc-local

# ---------------------------------------------------
# Final sanity checks
# ---------------------------------------------------
echo "[+] Running final sanity checks"

EMPTY_IP=$(mysql -u root "$DB_NAME" -N -e \
  "SELECT COUNT(*) FROM servers WHERE server_ip='';")

if [ "$EMPTY_IP" -gt 0 ]; then
  echo "[FATAL] Empty server_ip detected in DB"
  exit 1
fi

echo "[OK] Final sanity checks passed"
echo "=================================================="
echo "[OK] STEP 09 COMPLETED SUCCESSFULLY"
echo "=================================================="

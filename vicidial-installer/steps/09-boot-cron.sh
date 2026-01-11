#!/bin/bash
echo "=== STEP 09: Boot & VICIdial Cron Setup ==="

CRON_TMP="/tmp/vicidial_cron.tmp"

# Backup existing crontab (if any)
crontab -l > /tmp/cron.bak 2>/dev/null || true

# Remove existing VICIDIAL cron block if present
crontab -l 2>/dev/null | sed '/# VICIDIAL CRON START/,/# VICIDIAL CRON END/d' > "$CRON_TMP" || true

# Append VICIDIAL cron block
cat <<'EOF' >> "$CRON_TMP"

# VICIDIAL CRON START
### recording mixing/compressing/ftping scripts
0,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57 * * * * /usr/share/astguiclient/AST_CRON_audio_1_move_mix.pl --MIX
0,3,6,9,12,15,18,21,24,27,30,33,36,39,42,45,48,51,54,57 * * * * /usr/share/astguiclient/AST_CRON_audio_1_move_VDonly.pl
1,4,7,10,13,16,19,22,25,28,31,34,37,40,43,46,49,52,55,58 * * * * /usr/share/astguiclient/AST_CRON_audio_2_compress.pl --GSM

### keepalive script for astguiclient processes
* * * * * /usr/share/astguiclient/ADMIN_keepalive_ALL.pl --cu3way

### kill hung asterisk manager processes
* * * * * /usr/share/astguiclient/AST_manager_kill_hung_congested.pl

### voicemail update
* * * * * /usr/share/astguiclient/AST_vm_update.pl

### conference validator
* * * * * /usr/share/astguiclient/AST_conf_update.pl

### flush DB queue every hour
11 * * * * /usr/share/astguiclient/AST_flush_DBqueue.pl -q

### cleanup vicidial_agent_log
33 * * * * /usr/share/astguiclient/AST_cleanup_agent_log.pl
50 0 * * * /usr/share/astguiclient/AST_cleanup_agent_log.pl --last-24hours

### VICIDIAL hopper updater
* * * * * /usr/share/astguiclient/AST_VDhopper.pl -q

### GMT offset adjustment
1 1,7 * * * /usr/share/astguiclient/ADMIN_adjust_GMTnow_on_leads.pl --debug

### reset temporary DB tables
2 1 * * * /usr/share/astguiclient/AST_reset_mysql_vars.pl

### optimize DB tables
3 1 * * * /usr/share/astguiclient/AST_DB_optimize.pl

### time sync
30 * * * * /usr/sbin/ntpdate -u pool.ntp.org >/dev/null 2>&1

### agent stats
22 0 * * * /usr/share/astguiclient/AST_agent_day.pl
2 0 * * 0 /usr/share/astguiclient/AST_agent_week.pl

### remove old logs
28 0 * * * /usr/bin/find /var/log/astguiclient -type f -mtime +2 -delete
29 0 * * * /usr/bin/find /var/log/asterisk -type f -mtime +2 -delete

### inbound email parser
* * * * * /usr/share/astguiclient/AST_inbound_email_parser.pl
# VICIDIAL CRON END

EOF

# Install new crontab
crontab "$CRON_TMP"
rm -f "$CRON_TMP"

echo "[OK] VICIdial cron installed successfully"

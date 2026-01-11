#!/bin/bash
set -euo pipefail

echo "=================================================="
echo " ASTERISK AMI HEALTH CHECK"
echo "=================================================="

AMI_PORT=5038

# 1. Asterisk running
asterisk -rx "core show uptime" >/dev/null \
  || { echo "[FATAL] Asterisk CLI not responding"; exit 1; }

# 2. AMI port listening
ss -lntp | grep -q ":${AMI_PORT}" \
  || { echo "[FATAL] AMI port ${AMI_PORT} not listening"; exit 1; }

# 3. AMI login test (local)
AMI_USER=$(grep '^user=' /etc/asterisk/manager.conf | head -1 | cut -d= -f2)
AMI_PASS=$(grep '^secret=' /etc/asterisk/manager.conf | head -1 | cut -d= -f2)

[ -z "$AMI_USER" ] && { echo "[FATAL] AMI user not found"; exit 1; }
[ -z "$AMI_PASS" ] && { echo "[FATAL] AMI secret not found"; exit 1; }

echo "[+] Testing AMI login"

printf "Action: Login\r\nUsername: %s\r\nSecret: %s\r\n\r\n" \
  "$AMI_USER" "$AMI_PASS" | nc 127.0.0.1 ${AMI_PORT} | grep -q "Success" \
  || { echo "[FATAL] AMI login failed"; exit 1; }

echo "[OK] AMI login successful"
echo "=================================================="

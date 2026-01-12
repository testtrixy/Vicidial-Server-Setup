#!/bin/bash
set -euo pipefail

exec > >(tee -a "$LOG_FILE") 2>&1
echo "[RUNNING] $0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/config.env"

[ "${FAIL2BAN_ENABLE}" != "1" ] && {
  echo "[SKIP] Fail2Ban disabled"
  exit 0
}

echo "=================================================="
echo " STEP 10: Fail2Ban (SIP + AMI + WEB)"
echo "=================================================="

# Install packages
yum install -y fail2ban iptables-services

systemctl enable iptables
systemctl start iptables

systemctl enable fail2ban
systemctl start fail2ban

# Create directories
mkdir -p /etc/fail2ban/filter.d
mkdir -p /etc/fail2ban/jail.d

# Copy filters
cp "$ROOT_DIR/security/fail2ban/asterisk-sip.conf" \
   /etc/fail2ban/filter.d/

cp "$ROOT_DIR/security/fail2ban/asterisk-ami.conf" \
   /etc/fail2ban/filter.d/

# Copy jails
cp "$ROOT_DIR/security/fail2ban/jail-asterisk-sip.local" \
   /etc/fail2ban/jail.d/

cp "$ROOT_DIR/security/fail2ban/jail-asterisk-ami.local" \
   /etc/fail2ban/jail.d/

cp "$ROOT_DIR/security/fail2ban/jail-apache-vicidial.local" \
   /etc/fail2ban/jail.d/

# Replace variables
sed -i \
  -e "s/__SIP_PORTS__/${SIP_PORTS}/g" \
  /etc/fail2ban/jail.d/jail-asterisk-sip.local

sed -i \
  -e "s/__AMI_PORT__/${AMI_PORT}/g" \
  /etc/fail2ban/jail.d/jail-asterisk-ami.local

# Configure ignore IPs
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = ${FAIL2BAN_IGNORE_IPS}
EOF

# Restart
systemctl restart fail2ban

echo "[OK] Fail2Ban configured and started"

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT_DIR/config.env"

[ "${FAIL2BAN_ENABLE:-0}" != "1" ] && {
  echo "[SKIP] Fail2Ban disabled"
  exit 0
}

echo "=================================================="
echo " STEP 10: Fail2Ban (SIP + AMI + WEB)"
echo "=================================================="

# ---------------------------------------------------
# Install packages (idempotent)
# ---------------------------------------------------
dnf install -y fail2ban iptables-services

systemctl enable iptables
systemctl start iptables || true

systemctl enable fail2ban
systemctl start fail2ban || true

# ---------------------------------------------------
# Prepare directories
# ---------------------------------------------------
mkdir -p /etc/fail2ban/filter.d
mkdir -p /etc/fail2ban/jail.d

SEC_DIR="$ROOT_DIR/security/fail2ban"

# ---------------------------------------------------
# Helper: safe copy or generate
# ---------------------------------------------------
safe_copy() {
  local src="$1"
  local dst="$2"
  local name="$3"

  if [[ -f "$src" ]]; then
    cp -f "$src" "$dst"
    echo "[OK] Installed $name"
  else
    echo "[WARN] $name not found — generating default"
    return 1
  fi
}

# ---------------------------------------------------
# SIP filter
# ---------------------------------------------------
if ! safe_copy "$SEC_DIR/asterisk-sip.conf" \
    /etc/fail2ban/filter.d/asterisk-sip.conf "asterisk-sip filter"; then

cat <<'EOF' > /etc/fail2ban/filter.d/asterisk-sip.conf
[Definition]
failregex = NOTICE.* .*: Registration from .* failed
            NOTICE.* .*: Call from .* rejected
ignoreregex =
EOF
fi

# ---------------------------------------------------
# AMI filter
# ---------------------------------------------------
if ! safe_copy "$SEC_DIR/asterisk-ami.conf" \
    /etc/fail2ban/filter.d/asterisk-ami.conf "asterisk-ami filter"; then

cat <<'EOF' > /etc/fail2ban/filter.d/asterisk-ami.conf
[Definition]
failregex = .*Manager '.*' failed authentication from.*
ignoreregex =
EOF
fi

# ---------------------------------------------------
# SIP jail
# ---------------------------------------------------
if ! safe_copy "$SEC_DIR/jail-asterisk-sip.local" \
    /etc/fail2ban/jail.d/jail-asterisk-sip.local "SIP jail"; then

cat <<EOF > /etc/fail2ban/jail.d/jail-asterisk-sip.local
[asterisk-sip]
enabled = true
filter = asterisk-sip
action = iptables-allports[name=SIP]
logpath = /var/log/asterisk/messages
maxretry = 5
bantime = 3600
findtime = 600
port = ${SIP_PORTS}
EOF
fi

# ---------------------------------------------------
# AMI jail
# ---------------------------------------------------
if ! safe_copy "$SEC_DIR/jail-asterisk-ami.local" \
    /etc/fail2ban/jail.d/jail-asterisk-ami.local "AMI jail"; then

cat <<EOF > /etc/fail2ban/jail.d/jail-asterisk-ami.local
[asterisk-ami]
enabled = true
filter = asterisk-ami
action = iptables-allports[name=AMI]
logpath = /var/log/asterisk/messages
maxretry = 3
bantime = 3600
findtime = 600
port = ${AMI_PORT}
EOF
fi

# ---------------------------------------------------
# Apache jail
# ---------------------------------------------------
if ! safe_copy "$SEC_DIR/jail-apache-vicidial.local" \
    /etc/fail2ban/jail.d/jail-apache-vicidial.local "Apache jail"; then

cat <<'EOF' > /etc/fail2ban/jail.d/jail-apache-vicidial.local
[apache-vicidial]
enabled = true
filter = apache-auth
logpath = /var/log/httpd/*error_log
maxretry = 5
bantime = 3600
findtime = 600
EOF
fi

# ---------------------------------------------------
# Global ignore IPs
# ---------------------------------------------------
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
ignoreip = ${FAIL2BAN_IGNORE_IPS}
EOF

# ---------------------------------------------------
# Restart fail2ban safely
# ---------------------------------------------------
systemctl restart fail2ban

echo "[OK] Fail2Ban configured successfully"
echo "=================================================="
